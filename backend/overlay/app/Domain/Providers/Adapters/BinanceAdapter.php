<?php

namespace App\Domain\Providers\Adapters;

/** Optional module; only for services Binance permits for SARIFIO's business and jurisdiction. */
class BinanceAdapter extends OfficialAdapter
{
    public function credentialFields(): array
    {
        return [
            $this->baseField(),
            ['key' => 'api_key', 'label' => 'API key', 'secret' => true, 'required' => true],
            ['key' => 'api_secret', 'label' => 'API secret', 'secret' => true, 'required' => true],
            ['key' => 'merchant_id', 'label' => 'Merchant ID (if applicable)', 'secret' => false, 'required' => false],
            ...$this->webhookFields(),
        ];
    }
}
