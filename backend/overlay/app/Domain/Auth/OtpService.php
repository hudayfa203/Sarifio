<?php

namespace App\Domain\Auth;

use App\Models\OtpChallenge;
use App\Models\User;
use App\Support\ApiError;
use App\Support\Ids;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

/**
 * One-time codes: random per request, hashed at rest, short-lived,
 * single-use, attempt-limited and rate-limited per phone and per IP.
 * Delivery goes through configured channels (SMS / WhatsApp Business /
 * verified email). In staging with SANDBOX_OTP_REVEAL=true the fresh code is
 * also returned to the test app — never in production.
 */
class OtpService
{
    /** @return array{challenge:OtpChallenge, code:string} */
    public function request(string $phone, ?string $name, string $purpose, string $channel, ?string $ip): array
    {
        $cfg = config('sarifio.otp');
        $user = User::query()->where('phone', $phone)->first();

        if ($purpose === 'login' && ! $user) {
            throw ApiError::make('not_found', 'No SARIFIO account uses this number yet. Create one instead.', 404);
        }
        if ($purpose === 'register' && blank($name) && ! $user) {
            throw ApiError::make('validation_failed', 'Please enter your full name.', 422);
        }
        if (! in_array($channel, $this->channels($user), true)) {
            throw ApiError::make('validation_failed', 'That delivery channel is not available.', 422);
        }

        $last = OtpChallenge::query()->where('phone', $phone)->latest('id')->first();
        if ($last && $last->created_at->diffInSeconds(now()) < $cfg['resend_after_seconds']) {
            throw ApiError::make('otp_resend_too_soon', 'Please wait before requesting a new code.', 429);
        }
        if (OtpChallenge::query()->where('phone', $phone)->where('created_at', '>=', now()->subHour())->count() >= $cfg['max_per_phone_per_hour']
            || ($ip && OtpChallenge::query()->where('ip', $ip)->where('created_at', '>=', now()->subHour())->count() >= $cfg['max_per_ip_per_hour'])) {
            throw ApiError::make('too_many_requests', 'Too many code requests. Please try again later.', 429);
        }

        $code = str_pad((string) random_int(0, 10 ** $cfg['length'] - 1), $cfg['length'], '0', STR_PAD_LEFT);
        OtpChallenge::query()->where('phone', $phone)->whereNull('consumed_at')->update(['consumed_at' => now()]);
        $challenge = OtpChallenge::query()->create([
            'public_id' => Ids::make('otp_'),
            'phone' => $phone,
            'name' => $name,
            'purpose' => $purpose,
            'channel' => $channel,
            'code_hash' => Hash::make($code),
            'expires_at' => now()->addSeconds($cfg['ttl_seconds']),
            'ip' => $ip,
        ]);

        $this->deliver($channel, $phone, $user?->email, $code);

        return ['challenge' => $challenge, 'code' => $code];
    }

    public function verify(string $publicId, string $code): User
    {
        $c = OtpChallenge::query()->where('public_id', $publicId)->first();
        if (! $c || $c->consumed_at || $c->expires_at->isPast()) {
            throw ApiError::make('otp_expired', 'This code has expired. Request a new one.', 410);
        }
        if (! Hash::check($code, $c->code_hash)) {
            $c->increment('attempts');
            if ($c->attempts >= config('sarifio.otp.max_attempts')) {
                $c->update(['consumed_at' => now()]);
                throw ApiError::make('otp_attempts_exceeded', 'Too many wrong attempts. Request a new code.', 429);
            }
            throw ApiError::make('otp_invalid', 'That code is not correct.', 422);
        }
        $c->update(['consumed_at' => now()]);

        return User::query()->firstOrCreate(
            ['phone' => $c->phone],
            ['name' => $c->name ?: 'SARIFIO customer', 'is_test' => config('sarifio.mode') !== 'production'],
        );
    }

    /** Channels available for this customer. Email only once an email is verified. */
    public function channels(?User $user): array
    {
        $channels = array_values(array_filter(explode(',', (string) config('sarifio.otp.channels', 'sms'))));
        if (! $user?->email_verified_at) {
            $channels = array_values(array_diff($channels, ['email']));
        }

        return $channels ?: ['sms'];
    }

    private function deliver(string $channel, string $phone, ?string $email, string $code): void
    {
        $driver = config('sarifio.otp.driver', 'log');
        if ($driver === 'log') {
            // Staging without an SMS/WhatsApp provider: the code is logged (never in production).
            if (config('sarifio.mode') === 'production') {
                throw ApiError::make('otp_unavailable', 'Code delivery is not configured.', 503);
            }
            Log::info('Sandbox OTP issued', ['phone' => substr($phone, 0, 6).'…', 'channel' => $channel]);

            return;
        }
        // Real channel drivers (SMS gateway, WhatsApp Business, mail) are bound in
        // App\Providers\AppServiceProvider once credentials are configured.
        app(OtpSender::class)->send($channel, $phone, $email, $code);
    }
}
