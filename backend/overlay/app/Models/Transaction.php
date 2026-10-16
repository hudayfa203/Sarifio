<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Transaction extends Model
{
    public const STATUSES = [
        'created', 'quoted', 'awaiting_payment', 'payment_verified', 'payout_processing',
        'settled', 'failed', 'cancelled', 'manual_review', 'refunded',
    ];

    protected $fillable = [
        'public_id', 'reference', 'user_id', 'quote_id', 'from_provider_id', 'to_provider_id',
        'currency', 'receive_currency', 'amount_minor', 'fee_bps', 'fee_minor', 'provider_fee_minor',
        'rate_micro', 'rate_difference_minor', 'receive_minor', 'recipient_account', 'recipient_account_masked',
        'recipient_name', 'status', 'failure_reason', 'collection_ref', 'payout_ref', 'payout_attempts',
        'livemode', 'sandbox_outcome', 'settled_at',
    ];

    protected $hidden = ['recipient_account'];

    protected function casts(): array
    {
        return [
            'recipient_account' => 'encrypted',
            'livemode' => 'boolean',
            'settled_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function from(): BelongsTo
    {
        return $this->belongsTo(Provider::class, 'from_provider_id');
    }

    public function to(): BelongsTo
    {
        return $this->belongsTo(Provider::class, 'to_provider_id');
    }

    public function events(): HasMany
    {
        return $this->hasMany(TransactionEvent::class)->orderBy('id');
    }

    public function toApi(): array
    {
        $ref = fn (Provider $p) => ['code' => $p->code, 'name' => $p->name, 'group' => $p->group_name];

        return [
            'id' => $this->public_id,
            'reference' => $this->reference,
            'status' => $this->status,
            'test' => ! $this->livemode,
            'from' => $ref($this->from),
            'to' => $ref($this->to),
            'currency' => $this->currency,
            'receive_currency' => $this->receive_currency,
            'amount_minor' => (int) $this->amount_minor,
            'fee_bps' => (int) $this->fee_bps,
            'fee_minor' => (int) $this->fee_minor,
            'provider_fee_minor' => (int) $this->provider_fee_minor,
            'rate_micro' => (int) $this->rate_micro,
            'rate_difference_minor' => (int) $this->rate_difference_minor,
            'receive_minor' => (int) $this->receive_minor,
            'recipient_account' => $this->recipient_account_masked,
            'recipient_name' => $this->recipient_name,
            'events' => $this->events->map(fn ($e) => [
                'status' => $e->status,
                'at' => $e->created_at->toIso8601ZuluString(),
            ])->all(),
            'failure_reason' => $this->failure_reason,
            'created_at' => $this->created_at->toIso8601ZuluString(),
            'updated_at' => $this->updated_at->toIso8601ZuluString(),
        ];
    }
}
