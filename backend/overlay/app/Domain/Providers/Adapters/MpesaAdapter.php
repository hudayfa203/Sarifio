<?php

namespace App\Domain\Providers\Adapters;

use App\Domain\Providers\ProviderResult;
use Illuminate\Support\Facades\Http;
use Throwable;

/**
 * M-Pesa (Kenya, KES) via Safaricom's Daraja API. The connection test
 * requests a real OAuth token, so a passing test proves the consumer key and
 * secret work. Collection (STK Push / C2B) and payout (B2C) calls are to be
 * implemented and certified against the current Daraja documentation.
 */
class MpesaAdapter extends OfficialAdapter
{
    public function credentialFields(): array
    {
        return [
            ['key' => 'base_url', 'label' => 'Daraja base URL', 'secret' => false, 'required' => true,
                'help' => 'Sandbox and production hosts are listed in the Daraja portal.'],
            ['key' => 'consumer_key', 'label' => 'Consumer key', 'secret' => true, 'required' => true],
            ['key' => 'consumer_secret', 'label' => 'Consumer secret', 'secret' => true, 'required' => true],
            ['key' => 'shortcode', 'label' => 'Business short code (Paybill / Till)', 'secret' => false, 'required' => true],
            ['key' => 'passkey', 'label' => 'Lipa na M-Pesa passkey (STK Push)', 'secret' => true, 'required' => false],
            ['key' => 'initiator_name', 'label' => 'B2C initiator name', 'secret' => false, 'required' => false],
            ['key' => 'security_credential', 'label' => 'B2C security credential', 'secret' => true, 'required' => false],
            ...$this->webhookFields(),
        ];
    }

    public function docsUrl(): ?string
    {
        return 'https://developer.safaricom.co.ke';
    }

    public function testConnection(array $credentials, string $environment): ProviderResult
    {
        if ($missing = $this->missingField($credentials)) {
            return ProviderResult::failed("Missing required field: {$missing}.");
        }
        $base = rtrim((string) $credentials['base_url'], '/');
        if (! str_starts_with($base, 'https://')) {
            return ProviderResult::failed('The Daraja base URL must use HTTPS.');
        }
        try {
            $res = Http::timeout(15)
                ->withBasicAuth((string) $credentials['consumer_key'], (string) $credentials['consumer_secret'])
                ->get($base.'/oauth/v1/generate', ['grant_type' => 'client_credentials']);
        } catch (Throwable $e) {
            return ProviderResult::failed('Could not reach Daraja: '.$e->getMessage());
        }
        if ($res->successful() && filled($res->json('access_token'))) {
            return ProviderResult::ok(null, 'Daraja OAuth token issued. Money movement stays disabled until STK Push/B2C are certified and approved.');
        }

        return ProviderResult::failed('Daraja rejected the credentials (HTTP '.$res->status().').');
    }
}
