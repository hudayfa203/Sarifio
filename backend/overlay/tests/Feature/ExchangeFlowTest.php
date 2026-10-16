<?php

namespace Tests\Feature;

use App\Models\JournalLine;
use App\Models\LedgerAccount;
use App\Models\Provider;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * End-to-end sandbox flow (queue=sync, SARIFIO_MODE=sandbox, SANDBOX_OTP_REVEAL=true
 * — see phpunit.xml additions in backend/README.md).
 */
class ExchangeFlowTest extends TestCase
{
    use RefreshDatabase;

    protected bool $seed = true;

    private function signIn(string $phone = '+252906000001'): string
    {
        $otp = $this->postJson('/api/v1/auth/otp/request', [
            'phone' => $phone, 'name' => 'Test Customer', 'purpose' => 'register', 'channel' => 'sms',
        ])->assertCreated()->json();
        $this->assertMatchesRegularExpression('/^\d{6}$/', $otp['test_code']);

        return $this->postJson('/api/v1/auth/otp/verify', [
            'request_id' => $otp['request_id'], 'code' => $otp['test_code'], 'device_name' => 'phpunit',
        ])->assertOk()->json('token');
    }

    private function exchange(string $token, string $from, string $to, int $amount, ?string $key = null): array
    {
        $quote = $this->withToken($token)->postJson('/api/v1/quotes', [
            'from' => $from, 'to' => $to, 'amount_minor' => $amount,
        ])->assertCreated()->json();

        return $this->withToken($token)->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())
            ->postJson('/api/v1/exchanges', ['quote_id' => $quote['id'], 'recipient_account' => '+251911223344'])
            ->assertCreated()->json();
    }

    private function balance(string $code, string $currency): array
    {
        $acct = LedgerAccount::query()->where(['code' => $code, 'currency' => $currency, 'livemode' => false])->first();
        if (! $acct) {
            return [0, 0];
        }

        return [
            (int) JournalLine::query()->where('ledger_account_id', $acct->id)->sum('debit_minor'),
            (int) JournalLine::query()->where('ledger_account_id', $acct->id)->sum('credit_minor'),
        ];
    }

    public function test_config_lists_ebirr_and_mpesa_with_currencies(): void
    {
        $cfg = $this->getJson('/api/v1/config')->assertOk()->json();
        $codes = collect($cfg['providers'])->keyBy('code');
        $this->assertSame('ETB', $codes['ebirr']['currency']);
        $this->assertSame('KES', $codes['mpesa']['currency']);
        $this->assertSame(100, $cfg['fee']['bps']);
        $this->assertNotContains('live', collect($cfg['providers'])->pluck('status')->all());
    }

    public function test_sahal_to_ebirr_settles_with_balanced_books_and_fee_revenue(): void
    {
        $token = $this->signIn();
        $tx = $this->exchange($token, 'sahal', 'ebirr', 10000);

        $tx = $this->withToken($token)->getJson('/api/v1/exchanges/'.$tx['id'])->assertOk()->json();
        $this->assertSame('settled', $tx['status']);
        $this->assertSame('USD', $tx['currency']);
        $this->assertSame('ETB', $tx['receive_currency']);
        $this->assertSame(100, $tx['fee_minor']);
        $this->assertSame(1231313, $tx['receive_minor']);
        $this->assertTrue($tx['test']);

        foreach (['USD', 'ETB'] as $cur) {
            $rows = $this->getTrialBalance($cur);
            $this->assertSame(array_sum(array_column($rows, 'debit_minor')), array_sum(array_column($rows, 'credit_minor')), "{$cur} books balance");
        }
        $this->assertSame([0, 100], $this->balance('4000', 'USD'));      // 1% fee revenue
        $this->assertSame([0, 6187], $this->balance('4100', 'ETB'));     // FX spread, separate from the fee
        $this->assertSame([10000, 10000], $this->balance('2100', 'USD')); // customer liability cleared
    }

    public function test_failed_payout_is_refunded_and_earns_no_fee(): void
    {
        $token = $this->signIn();
        $this->withToken($token)->postJson('/api/v1/sandbox/next-outcome', ['outcome' => 'fail_payout'])->assertNoContent();
        $tx = $this->exchange($token, 'evc_plus', 'mpesa', 5000);
        $tx = $this->withToken($token)->getJson('/api/v1/exchanges/'.$tx['id'])->json();

        $this->assertSame('refunded', $tx['status']);
        $this->assertSame([0, 0], $this->balance('4000', 'USD'));
    }

    public function test_idempotency_replays_and_rejects_conflicts(): void
    {
        $token = $this->signIn();
        $key = (string) Str::uuid();
        $quote = $this->withToken($token)->postJson('/api/v1/quotes', ['from' => 'sahal', 'to' => 'edahab', 'amount_minor' => 2000])->json();
        $body = ['quote_id' => $quote['id'], 'recipient_account' => '+252621234567'];

        $a = $this->withToken($token)->withHeader('Idempotency-Key', $key)->postJson('/api/v1/exchanges', $body)->assertCreated()->json();
        $b = $this->withToken($token)->withHeader('Idempotency-Key', $key)->postJson('/api/v1/exchanges', $body)->assertCreated()->json();
        $this->assertSame($a['id'], $b['id']);

        $this->withToken($token)->withHeader('Idempotency-Key', $key)
            ->postJson('/api/v1/exchanges', $body + ['recipient_name' => 'Someone else'])
            ->assertStatus(409)->assertJsonPath('error.code', 'idempotency_conflict');
    }

    public function test_ebirr_and_mpesa_cannot_go_live_without_approvals(): void
    {
        foreach (['ebirr', 'mpesa'] as $code) {
            $blockers = Provider::query()->where('code', $code)->firstOrFail()->goLiveBlockers();
            $this->assertNotEmpty($blockers);
        }
    }

    private function getTrialBalance(string $currency): array
    {
        return app(\App\Domain\Ledger\Ledger::class)->trialBalance($currency, false);
    }
}
