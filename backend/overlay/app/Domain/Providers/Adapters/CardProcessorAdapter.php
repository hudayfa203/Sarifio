<?php

namespace App\Domain\Providers\Adapters;

/**
 * Visa acceptance through an authorised card processor, using hosted /
 * tokenised payment pages. SARIFIO never stores raw card numbers. Card
 * collection does not imply the ability to pay out to a wallet.
 */
class CardProcessorAdapter extends OfficialAdapter
{
    public function credentialFields(): array
    {
        return [
            ['key' => 'processor', 'label' => 'Processor name', 'secret' => false, 'required' => true],
            $this->baseField(),
            ['key' => 'public_key', 'label' => 'Publishable key', 'secret' => false, 'required' => true],
            ['key' => 'secret_key', 'label' => 'Secret key', 'secret' => true, 'required' => true],
            ...$this->webhookFields(),
        ];
    }
}
