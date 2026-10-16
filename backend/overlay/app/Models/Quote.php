<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Quote extends Model
{
    protected $fillable = [
        'public_id', 'user_id', 'from_provider_id', 'to_provider_id', 'currency', 'receive_currency',
        'amount_minor', 'fee_bps', 'fee_minor', 'provider_fee_minor', 'mid_rate_micro', 'rate_micro',
        'rate_difference_minor', 'receive_minor', 'expires_at', 'used_at', 'livemode',
    ];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'used_at' => 'datetime', 'livemode' => 'boolean'];
    }

    public function from(): BelongsTo
    {
        return $this->belongsTo(Provider::class, 'from_provider_id');
    }

    public function to(): BelongsTo
    {
        return $this->belongsTo(Provider::class, 'to_provider_id');
    }

    public function toApi(): array
    {
        return [
            'id' => $this->public_id,
            'from' => $this->from->code,
            'to' => $this->to->code,
            'currency' => $this->currency,
            'receive_currency' => $this->receive_currency,
            'amount_minor' => (int) $this->amount_minor,
            'fee_bps' => (int) $this->fee_bps,
            'fee_minor' => (int) $this->fee_minor,
            'provider_fee_minor' => (int) $this->provider_fee_minor,
            'mid_rate_micro' => (int) $this->mid_rate_micro,
            'rate_micro' => (int) $this->rate_micro,
            'rate_difference_minor' => (int) $this->rate_difference_minor,
            'receive_minor' => (int) $this->receive_minor,
            'expires_at' => $this->expires_at->toIso8601ZuluString(),
        ];
    }
}
