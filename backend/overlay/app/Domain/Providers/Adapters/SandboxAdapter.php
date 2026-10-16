<?php

namespace App\Domain\Providers\Adapters;

use App\Domain\Providers\ProviderAdapter;
use App\Domain\Providers\ProviderResult;
use App\Models\Provider;
use App\Models\Transaction;
use App\Support\Ids;
use Illuminate\Http\Request;

/**
 * Simulated provider used for every wallet in sandbox mode (staging / Test
 * Mode). Outcomes follow the user's "next exchange result" setting so the
 * Samsung test app can exercise success, failures, refunds and review.
 * No network calls, no real money.
 */
class SandboxAdapter implements ProviderAdapter
{
    public function __construct(protected Provider $provider) {}

    public function credentialFields(): array
    {
        return [];
    }

    public function docsUrl(): ?string
    {
        return null;
    }

    public function testConnection(array $credentials, string $environment): ProviderResult
    {
        return ProviderResult::ok(null, 'Sandbox simulator is available.');
    }

    public function requestCollection(Transaction $tx, array $credentials, string $environment): ProviderResult
    {
        return $tx->sandbox_outcome === 'fail_payment'
            ? ProviderResult::failed('The sending provider declined the payment (simulated).', Ids::make('SBXC-', 10))
            : ProviderResult::ok(Ids::make('SBXC-', 10), 'Collection confirmed (simulated).');
    }

    public function requestPayout(Transaction $tx, string $account, array $credentials, string $environment): ProviderResult
    {
        return match ($tx->sandbox_outcome) {
            'fail_payout' => ProviderResult::failed('The receiving provider rejected the payout (simulated).', Ids::make('SBXP-', 10)),
            'manual_review' => ProviderResult::pending(Ids::make('SBXP-', 10), 'Held for review (simulated).'),
            default => ProviderResult::ok(Ids::make('SBXP-', 10), 'Payout confirmed (simulated).'),
        };
    }

    public function queryStatus(Transaction $tx, string $leg, array $credentials, string $environment): ProviderResult
    {
        return ProviderResult::ok($leg === 'collection' ? $tx->collection_ref : $tx->payout_ref);
    }

    public function verifyWebhook(Request $request, ?string $secret): bool
    {
        return false; // the simulator never sends webhooks
    }

    public function parseWebhook(Request $request): array
    {
        return [];
    }
}
