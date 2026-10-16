<?php

namespace App\Domain\Providers\Adapters;

/** One WaafiPay integration serving both Sahal and EVC Plus (payment method per provider row). */
class WaafiPayAdapter extends OfficialAdapter
{
    public function credentialFields(): array
    {
        return [
            $this->baseField(),
            ['key' => 'merchant_uid', 'label' => 'Merchant UID', 'secret' => false, 'required' => true],
            ['key' => 'api_user_id', 'label' => 'API user ID', 'secret' => false, 'required' => true],
            ['key' => 'api_key', 'label' => 'API key', 'secret' => true, 'required' => true],
            ['key' => 'payment_method', 'label' => 'Payment method code', 'secret' => false, 'required' => false,
                'help' => 'Method for this wallet ('.($this->definition['method'] ?? 'sahal').') as named in the WaafiPay specification.'],
            ...$this->webhookFields(),
        ];
    }
}
