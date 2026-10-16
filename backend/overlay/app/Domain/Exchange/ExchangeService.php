<?php

namespace App\Domain\Exchange;

use App\Domain\Ledger\Ledger;
use App\Domain\Money\FeeEngine;
use App\Domain\Providers\ProviderRegistry;
use App\Domain\Providers\ProviderResult;
use App\Jobs\ProcessExchange;
use App\Models\ExchangeRoute;
use App\Models\FeeSetting;
use App\Models\FxRate;
use App\Models\IdempotencyKey;
use App\Models\Provider;
use App\Models\Quote;
use App\Models\Transaction;
use App\Models\User;
use App\Support\ApiError;
use App\Support\Ids;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use LogicException;

/**
 * Quotes, exchange creation (idempotent) and the transaction state machine:
 *
 *   created → quoted → awaiting_payment → payment_verified → payout_processing → settled
 *   with controlled exits to failed, cancelled, manual_review and refunded.
 *
 * A transaction is only "settled" after the payout provider confirms it
 * (adapter result, verified webhook or status query) — never because a
 * client says so. Each leg is guarded by a row lock so money is never sent twice.
 */
class ExchangeService
{
    private const TRANSITIONS = [
        'created' => ['quoted', 'cancelled'],
        'quoted' => ['awaiting_payment', 'cancelled'],
        'awaiting_payment' => ['payment_verified', 'failed', 'cancelled'],
        'payment_verified' => ['payout_processing', 'manual_review', 'refunded'],
        'payout_processing' => ['settled', 'failed', 'manual_review'],
        'manual_review' => ['payout_processing', 'settled', 'refunded', 'failed'],
        'failed' => ['refunded'],
        'settled' => ['refunded'],
        'cancelled' => [],
        'refunded' => [],
    ];

    public function __construct(private Ledger $ledger, private ProviderRegistry $providers) {}

    public function livemode(): bool
    {
        return config('sarifio.mode') === 'production';
    }

    // ------------------------------------------------------------------ quotes

    public function quote(User $user, string $fromCode, string $toCode, int $amountMinor): Quote
    {
        $from = Provider::query()->where('code', $fromCode)->first();
        $to = Provider::query()->where('code', $toCode)->first();
        if (! $from || ! $to) {
            throw ApiError::make('not_found', 'Unknown provider.', 404);
        }
        $route = ExchangeRoute::query()->where(['from_provider_id' => $from->id, 'to_provider_id' => $to->id])->first();
        if (! $route || ! $route->available()) {
            throw ApiError::make('route_disabled', 'This exchange route is not available yet.', 403);
        }
        if ($user->status !== 'active') {
            throw ApiError::make('account_restricted', 'Your account is restricted. Please contact support.', 403);
        }
        [$mid, $spread] = FxRate::for($from->currency, $to->currency);

        $usd = FxRate::for($from->currency, 'USD');
        $usdEquivalent = $usd ? FeeEngine::convert($amountMinor, $usd[0]) : $amountMinor;
        if ($usdEquivalent < 100 || ($route->min_minor && $amountMinor < $route->min_minor)) {
            throw ApiError::make('amount_out_of_range', 'The amount is below the minimum for this route.', 422);
        }
        if ($route->max_minor && $amountMinor > $route->max_minor) {
            throw ApiError::make('amount_out_of_range', 'The amount is above the maximum for this route.', 422);
        }
        if ($usdEquivalent > $user->per_tx_limit_usd_cents) {
            throw ApiError::make('limit_exceeded', 'This amount is above your per-exchange limit.', 403);
        }
        $todayUsd = $this->todayUsdVolume($user);
        if ($todayUsd + $usdEquivalent > $user->daily_limit_usd_cents) {
            throw ApiError::make('limit_exceeded', 'This amount would exceed your daily limit.', 403);
        }

        $feeBps = FeeSetting::currentBps();
        $m = FeeEngine::quote($amountMinor, $feeBps, (int) $route->provider_fee_bps, $mid, $spread);

        return Quote::query()->create([
            'public_id' => Ids::make('qt_'),
            'user_id' => $user->id,
            'from_provider_id' => $from->id,
            'to_provider_id' => $to->id,
            'currency' => $from->currency,
            'receive_currency' => $to->currency,
            'amount_minor' => $amountMinor,
            'fee_bps' => $feeBps,
            'fee_minor' => $m['fee_minor'],
            'provider_fee_minor' => $m['provider_fee_minor'],
            'mid_rate_micro' => $mid,
            'rate_micro' => $m['rate_micro'],
            'rate_difference_minor' => $m['rate_difference_minor'],
            'receive_minor' => $m['receive_minor'],
            'expires_at' => now()->addSeconds((int) config('sarifio.quote_ttl_seconds', 60)),
            'livemode' => $this->livemode(),
        ]);
    }

    private function todayUsdVolume(User $user): int
    {
        $sum = 0;
        $rows = Transaction::query()
            ->where('user_id', $user->id)
            ->where('created_at', '>=', now()->startOfDay())
            ->whereNotIn('status', ['failed', 'cancelled', 'refunded'])
            ->get(['currency', 'amount_minor']);
        foreach ($rows as $r) {
            $usd = FxRate::for($r->currency, 'USD');
            $sum += $usd ? FeeEngine::convert((int) $r->amount_minor, $usd[0]) : (int) $r->amount_minor;
        }

        return $sum;
    }

    // ------------------------------------------------------------------ create

    /**
     * Idempotent: the same Idempotency-Key + body returns the original
     * transaction; the same key with a different body is a 409.
     */
    public function create(User $user, string $idempotencyKey, string $quoteId, string $account, ?string $name): Transaction
    {
        $hash = hash('sha256', json_encode([$quoteId, $account, $name]));

        $existing = IdempotencyKey::query()->where(['user_id' => $user->id, 'key' => $idempotencyKey])->first();
        if ($existing) {
            return $this->replay($existing, $hash);
        }

        try {
            $tx = DB::transaction(function () use ($user, $idempotencyKey, $hash, $quoteId, $account, $name) {
                IdempotencyKey::query()->create(['user_id' => $user->id, 'key' => $idempotencyKey, 'request_hash' => $hash]);

                /** @var Quote|null $quote */
                $quote = Quote::query()->where(['public_id' => $quoteId, 'user_id' => $user->id])->lockForUpdate()->first();
                if (! $quote) {
                    throw ApiError::make('not_found', 'Quote not found.', 404);
                }
                if ($quote->used_at) {
                    throw ApiError::make('quote_already_used', 'This quote was already used. Please get a new quote.', 409);
                }
                if ($quote->expires_at->isPast()) {
                    throw ApiError::make('quote_expired', 'This quote has expired. Please refresh it.', 410);
                }
                $digits = preg_replace('/\D/', '', $account) ?? '';
                if (strlen($digits) < 7 || strlen($digits) > 15) {
                    throw ApiError::make('validation_failed', 'Please enter the receiving account number.', 422);
                }
                $quote->update(['used_at' => now()]);

                $tx = Transaction::query()->create([
                    'public_id' => Ids::make('tx_'),
                    'reference' => Ids::reference($quote->livemode),
                    'user_id' => $user->id,
                    'quote_id' => $quote->id,
                    'from_provider_id' => $quote->from_provider_id,
                    'to_provider_id' => $quote->to_provider_id,
                    'currency' => $quote->currency,
                    'receive_currency' => $quote->receive_currency,
                    'amount_minor' => $quote->amount_minor,
                    'fee_bps' => $quote->fee_bps,
                    'fee_minor' => $quote->fee_minor,
                    'provider_fee_minor' => $quote->provider_fee_minor,
                    'rate_micro' => $quote->rate_micro,
                    'rate_difference_minor' => $quote->rate_difference_minor,
                    'receive_minor' => $quote->receive_minor,
                    'recipient_account' => $digits,
                    'recipient_account_masked' => Ids::mask($digits),
                    'recipient_name' => $name ?: null,
                    'status' => 'created',
                    'livemode' => $quote->livemode,
                    'sandbox_outcome' => $quote->livemode ? null : $user->sandbox_next_outcome,
                ]);
                $tx->events()->create(['status' => 'created']);
                $this->transition($tx, 'quoted');
                $this->transition($tx, 'awaiting_payment');

                if (! $quote->livemode) {
                    $user->update(['sandbox_next_outcome' => 'success']); // applies to one exchange only
                }

                IdempotencyKey::query()->where(['user_id' => $user->id, 'key' => $idempotencyKey])
                    ->update(['transaction_id' => $tx->id, 'response_status' => 201]);

                return $tx;
            });
        } catch (UniqueConstraintViolationException) {
            // A concurrent request with the same key won the race.
            return $this->replay(IdempotencyKey::query()->where(['user_id' => $user->id, 'key' => $idempotencyKey])->firstOrFail(), $hash);
        }

        ProcessExchange::dispatch($tx->id, 'collect')
            ->delay(now()->addSeconds($tx->livemode ? 0 : 3)) // sandbox: the customer "approves" after a moment
            ->afterCommit();

        return $tx->fresh(['from', 'to', 'events']);
    }

    private function replay(IdempotencyKey $key, string $hash): Transaction
    {
        if (! hash_equals($key->request_hash, $hash)) {
            throw ApiError::make('idempotency_conflict', 'This request key was already used for a different exchange.', 409);
        }
        if (! $key->transaction_id) {
            throw ApiError::make('idempotency_conflict', 'The original request is still being processed. Try again shortly.', 409);
        }

        return Transaction::query()->with(['from', 'to', 'events'])->findOrFail($key->transaction_id);
    }

    // ----------------------------------------------------------- state machine

    public function transition(Transaction $tx, string $to, ?string $note = null, array $attributes = []): void
    {
        $allowed = self::TRANSITIONS[$tx->status] ?? [];
        if (! in_array($to, $allowed, true)) {
            throw new LogicException("Illegal transition {$tx->status} → {$to} for {$tx->reference}.");
        }
        $tx->fill($attributes + ['status' => $to]);
        if ($to === 'settled') {
            $tx->settled_at = now();
        }
        $tx->save();
        $tx->events()->create(['status' => $to, 'note' => $note]);
    }

    /** Step 1: ask the sending wallet to pay. */
    public function collect(int $txId): ?string
    {
        return DB::transaction(function () use ($txId) {
            $tx = Transaction::query()->lockForUpdate()->findOrFail($txId);
            if ($tx->status !== 'awaiting_payment') {
                return null; // already handled — idempotent
            }
            $adapter = $this->providers->forMoneyMovement($tx->from);
            $result = $adapter->requestCollection($tx, $this->providers->credentials($tx->from), $this->providers->environment());

            return $this->applyCollectionResult($tx, $result);
        });
    }

    /** Called by the job, a verified webhook or a status query. Returns the next step. */
    public function applyCollectionResult(Transaction $tx, ProviderResult $result): ?string
    {
        if ($result->status === ProviderResult::PENDING) {
            $tx->update(['collection_ref' => $result->reference ?? $tx->collection_ref]);

            return null; // wait for webhook
        }
        if (! $result->succeeded()) {
            $this->transition($tx, 'failed', $result->message, ['failure_reason' => $result->message, 'collection_ref' => $result->reference]);

            return null; // nothing collected → nothing to refund, no fee
        }
        $this->transition($tx, 'payment_verified', $result->message, ['collection_ref' => $result->reference]);
        $live = $tx->livemode;
        $this->ledger->post('collection_verified', $tx, $tx->currency, $live, "Collection {$tx->reference}", [
            [$this->ledger->clearing($tx->from, $tx->currency, $live), (int) $tx->amount_minor, 0],
            [$this->ledger->customerFundsPending($tx->currency, $live), 0, (int) $tx->amount_minor],
        ]);

        return 'payout';
    }

    /** Step 2: send to the receiving wallet — at most once. */
    public function payout(int $txId): void
    {
        DB::transaction(function () use ($txId) {
            $tx = Transaction::query()->lockForUpdate()->findOrFail($txId);
            if ($tx->status !== 'payment_verified' || $tx->payout_attempts > 0) {
                return; // never send twice
            }
            $this->transition($tx, 'payout_processing', null, ['payout_attempts' => $tx->payout_attempts + 1]);
            $adapter = $this->providers->forMoneyMovement($tx->to);
            $result = $adapter->requestPayout($tx, (string) $tx->recipient_account, $this->providers->credentials($tx->to), $this->providers->environment());
            $this->applyPayoutResult($tx, $result);
        });
    }

    public function applyPayoutResult(Transaction $tx, ProviderResult $result): void
    {
        if ($result->status === ProviderResult::PENDING) {
            $tx->update(['payout_ref' => $result->reference]);
            if (! $tx->livemode && $tx->sandbox_outcome === 'manual_review') {
                $this->transition($tx, 'manual_review', 'This exchange is being reviewed by our team (simulated).',
                    ['failure_reason' => 'This exchange is being reviewed by our team (simulated).']);
            }

            return;
        }
        if ($result->succeeded()) {
            $this->transition($tx, 'settled', $result->message, ['payout_ref' => $result->reference]);
            $this->postSettlement($tx);

            return;
        }
        if ($tx->livemode) {
            // Real funds: returning them needs a provider reversal, so operations
            // handle it from the review queue instead of an automatic ledger refund.
            $this->transition($tx, 'manual_review', $result->message, [
                'payout_ref' => $result->reference,
                'failure_reason' => 'Payout failed. Our team is returning your money.',
            ]);

            return;
        }
        $this->transition($tx, 'failed', $result->message, ['payout_ref' => $result->reference]);
        $this->refund($tx, 'Payout failed: '.$result->message.' Your money was returned.');
    }

    private function postSettlement(Transaction $tx): void
    {
        $live = $tx->livemode;
        $src = $tx->currency;
        $dst = $tx->receive_currency;
        $amount = (int) $tx->amount_minor;
        $fee = (int) $tx->fee_minor;
        $pfee = (int) $tx->provider_fee_minor;
        $net = $amount - $fee - $pfee;
        $receive = (int) $tx->receive_minor;
        $diff = (int) $tx->rate_difference_minor;

        if ($src === $dst) {
            $this->ledger->post('payout_settled', $tx, $src, $live, "Settlement {$tx->reference}", [
                [$this->ledger->customerFundsPending($src, $live), $amount, 0],
                [$this->ledger->feeRevenue($src, $live), 0, $fee],
                [$this->ledger->providerChargesPayable($src, $live), 0, $pfee],
                [$this->ledger->clearing($tx->to, $src, $live), 0, $receive],
            ]);

            return;
        }
        // Source currency: release the liability into fee revenue + FX position.
        $this->ledger->post('payout_settled', $tx, $src, $live, "Settlement {$tx->reference} ({$src})", [
            [$this->ledger->customerFundsPending($src, $live), $amount, 0],
            [$this->ledger->feeRevenue($src, $live), 0, $fee],
            [$this->ledger->providerChargesPayable($src, $live), 0, $pfee],
            [$this->ledger->fxPosition($src, $live), 0, $net],
        ]);
        // Destination currency: pay out from the receiving clearing account; spread is FX income.
        $this->ledger->post('payout_settled', $tx, $dst, $live, "Settlement {$tx->reference} ({$dst})", [
            [$this->ledger->fxPosition($dst, $live), $receive + $diff, 0],
            [$this->ledger->fxSpreadIncome($dst, $live), 0, $diff],
            [$this->ledger->clearing($tx->to, $dst, $live), 0, $receive],
        ]);
    }

    /** Return collected funds to the sender. No SARIFIO fee is earned. */
    public function refund(Transaction $tx, string $reason): void
    {
        $live = $tx->livemode;
        $this->ledger->post('refund', $tx, $tx->currency, $live, "Refund {$tx->reference}", [
            [$this->ledger->customerFundsPending($tx->currency, $live), (int) $tx->amount_minor, 0],
            [$this->ledger->clearing($tx->from, $tx->currency, $live), 0, (int) $tx->amount_minor],
        ]);
        $this->transition($tx, 'refunded', $reason, ['failure_reason' => $reason]);
    }
}
