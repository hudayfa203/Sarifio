<?php

namespace App\Domain\Providers\Adapters;

class PremierWalletAdapter extends OfficialAdapter
{
    public function credentialFields(): array
    {
        return [
            $this->baseField(),
            ['key' => 'merchant_id', 'label' => 'Merchant ID', 'secret' => false, 'required' => true],
            ['key' => 'api_key', 'label' => 'API key', 'secret' => true, 'required' => true],
            ['key' => 'api_secret', 'label' => 'API secret', 'secret' => true, 'required' => true],
            ...$this->webhookFields(),
        ];
    }
}
