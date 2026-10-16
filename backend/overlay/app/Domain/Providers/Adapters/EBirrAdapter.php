<?php

namespace App\Domain\Providers\Adapters;

/**
 * eBirr (Ethiopia, ETB). Field names follow the generic merchant pattern;
 * align them with eBirr's official merchant API documentation when access
 * is granted. Cross-border use also requires the applicable Ethiopian
 * regulatory approvals before go-live.
 */
class EBirrAdapter extends OfficialAdapter
{
    public function credentialFields(): array
    {
        return [
            $this->baseField(),
            ['key' => 'merchant_id', 'label' => 'Merchant ID / short code', 'secret' => false, 'required' => true],
            ['key' => 'client_id', 'label' => 'Client ID / username', 'secret' => false, 'required' => true],
            ['key' => 'client_secret', 'label' => 'Client secret / API key', 'secret' => true, 'required' => true],
            ['key' => 'extra', 'label' => 'Additional provider-specific settings (JSON)', 'secret' => true, 'required' => false],
            ...$this->webhookFields(),
        ];
    }
}
