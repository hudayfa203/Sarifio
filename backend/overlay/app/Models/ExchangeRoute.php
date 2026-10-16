<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class ExchangeRoute extends Model
{
    protected $fillable = ['from_provider_id', 'to_provider_id', 'enabled', 'provider_fee_bps', 'min_minor', 'max_minor'];

    protected function casts(): array
    {
        return ['enabled' => 'boolean'];
    }

    public function from(): BelongsTo
    {
        return $this->belongsTo(Provider::class, 'from_provider_id');
    }

    public function to(): BelongsTo
    {
        return $this->belongsTo(Provider::class, 'to_provider_id');
    }

    /** Offered only when enabled, both sides usable with the right capability, and a rate exists. */
    public function available(): bool
    {
        $from = $this->from;
        $to = $this->to;

        return $this->enabled
            && $from->usable() && $from->can_collect
            && $to->usable() && $to->can_payout
            && FxRate::for($from->currency, $to->currency) !== null;
    }
}
