<?php

namespace App\Providers;

use App\Domain\Ledger\Ledger;
use App\Domain\Providers\ProviderRegistry;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;
use RuntimeException;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(ProviderRegistry::class);
        $this->app->singleton(Ledger::class);
    }

    public function boot(): void
    {
        // Production safety: never reveal OTPs, never run with debug on.
        if (config('sarifio.mode') === 'production') {
            if (config('sarifio.otp_reveal')) {
                throw new RuntimeException('SANDBOX_OTP_REVEAL must be false in production.');
            }
            if (config('app.debug')) {
                throw new RuntimeException('APP_DEBUG must be false in production.');
            }
        }

        RateLimiter::for('api', fn (Request $r) => Limit::perMinute(120)->by($r->user()?->getAuthIdentifier() ?: $r->ip()));
        RateLimiter::for('otp', fn (Request $r) => [Limit::perMinute(6)->by($r->ip()), Limit::perHour(30)->by($r->ip())]);
        RateLimiter::for('money', fn (Request $r) => Limit::perMinute(20)->by($r->user()?->getAuthIdentifier() ?: $r->ip()));
        RateLimiter::for('webhooks', fn (Request $r) => Limit::perMinute(600)->by($r->ip()));
    }
}
