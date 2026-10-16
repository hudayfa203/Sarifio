<?php

namespace App\Domain\Providers;

use App\Models\Transaction;
use Illuminate\Http\Request;

/**
 * Contract every payment provider implements. A new wallet (any future
 * African mobile-money service) = one class implementing this interface,
 * registered in config/sarifio.php, then configured by an admin.
 */
interface ProviderAdapter
{
    /**
     * Fields the Admin API Integration Manager renders for this provider.
     *
     * @return list<array{key:string,label:string,secret:bool,required:bool,help?:string}>
     */
    public function credentialFields(): array;

    /** Official documentation / onboarding URL shown to admins. */
    public function docsUrl(): ?string;

    public function testConnection(array $credentials, string $environment): ProviderResult;

    /** Ask the customer's sending wallet to pay (push prompt / payment request). */
    public function requestCollection(Transaction $tx, array $credentials, string $environment): ProviderResult;

    /** Send money to the receiving wallet. Must be idempotent on $tx->reference. */
    public function requestPayout(Transaction $tx, string $account, array $credentials, string $environment): ProviderResult;

    /** Authoritative status check (used when webhooks are late or missing). */
    public function queryStatus(Transaction $tx, string $leg, array $credentials, string $environment): ProviderResult;

    /** Verify the webhook signature/origin. Unverified webhooks are rejected. */
    public function verifyWebhook(Request $request, ?string $secret): bool;

    /** @return array{leg:string, reference:string, result:ProviderResult} */
    public function parseWebhook(Request $request): array;
}
