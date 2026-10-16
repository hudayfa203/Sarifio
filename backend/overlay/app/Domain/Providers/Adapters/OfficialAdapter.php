<?php

namespace App\Domain\Providers\Adapters;

use App\Domain\Providers\IntegrationNotReady;
use App\Domain\Providers\ProviderAdapter;
use App\Domain\Providers\ProviderResult;
use App\Models\Provider;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * Base for official provider adapters. Until a provider's official API
 * specification and agreement are in hand, money-moving calls throw
 * IntegrationNotReady — the platform never pretends an integration works.
 * The connection test validates the configured credentials' shape and
 * that the configured base URL is reachable over HTTPS.
 */
abstract class OfficialAdapter implements ProviderAdapter
{
    public function __construct(protected Provider $provider, protected array $definition = []) {}

    protected function baseField(): array
    {
        return ['key' => 'base_url', 'label' => 'API base URL', 'secret' => false, 'required' => true,
            'help' => 'From the provider\'s official documentation (sandbox and production differ).'];
    }

    protected function webhookFields(): array
    {
        return [
            ['key' => 'webhook_secret', 'label' => 'Webhook signing secret', 'secret' => true, 'required' => false],
            ['key' => 'callback_ip_allowlist', 'label' => 'Callback IP allow-list (comma separated)', 'secret' => false, 'required' => false],
        ];
    }

    public function docsUrl(): ?string
    {
        return null;
    }

    /** Label of the first missing required credential, or null. */
    protected function missingField(array $credentials): ?string
    {
        foreach ($this->credentialFields() as $f) {
            if ($f['required'] && blank($credentials[$f['key']] ?? null)) {
                return $f['label'];
            }
        }

        return null;
    }

    public function testConnection(array $credentials, string $environment): ProviderResult
    {
        if ($missing = $this->missingField($credentials)) {
            return ProviderResult::failed("Missing required field: {$missing}.");
        }
        $base = (string) ($credentials['base_url'] ?? '');
        if ($base !== '') {
            if (! str_starts_with($base, 'https://')) {
                return ProviderResult::failed('The API base URL must use HTTPS.');
            }
            try {
                Http::timeout(10)->get($base);
            } catch (Throwable $e) {
                return ProviderResult::failed('Could not reach the API base URL: '.$e->getMessage());
            }
        }

        return ProviderResult::ok(null, 'Credentials are complete and the endpoint is reachable. '
            .'Money movement stays disabled until the official integration is implemented and approved.');
    }

    public function requestCollection(Transaction $tx, array $credentials, string $environment): ProviderResult
    {
        throw new IntegrationNotReady("{$this->provider->name}: collection must be implemented against the official API specification.");
    }

    public function requestPayout(Transaction $tx, string $account, array $credentials, string $environment): ProviderResult
    {
        throw new IntegrationNotReady("{$this->provider->name}: payout must be implemented against the official API specification.");
    }

    public function queryStatus(Transaction $tx, string $leg, array $credentials, string $environment): ProviderResult
    {
        throw new IntegrationNotReady("{$this->provider->name}: status query must be implemented against the official API specification.");
    }

    public function verifyWebhook(Request $request, ?string $secret): bool
    {
        if (blank($secret)) {
            return false; // never accept unsigned callbacks
        }
        $given = (string) $request->header('X-Signature', '');
        $expected = hash_hmac('sha256', $request->getContent(), (string) $secret);

        return $given !== '' && hash_equals($expected, $given);
    }

    public function parseWebhook(Request $request): array
    {
        throw new IntegrationNotReady("{$this->provider->name}: webhook format must follow the official specification.");
    }
}
