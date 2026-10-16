<?php

namespace App\Models;

use App\Support\Ids;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

/** A SARIFIO customer. Registers with name + phone; verified by OTP. */
class User extends Authenticatable
{
    use HasApiTokens, Notifiable;

    protected $fillable = [
        'name', 'phone', 'email', 'language', 'kyc_status',
        'per_tx_limit_usd_cents', 'daily_limit_usd_cents', 'status', 'is_test', 'sandbox_next_outcome',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_test' => 'boolean',
        ];
    }

    protected static function booted(): void
    {
        static::creating(fn (User $u) => $u->public_id ??= Ids::make('usr_'));
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function toApi(): array
    {
        return [
            'id' => $this->public_id,
            'name' => $this->name,
            'phone' => $this->phone,
            'email' => $this->email,
            'email_verified' => $this->email_verified_at !== null,
            'language' => $this->language,
            'kyc_status' => $this->kyc_status,
            'limits' => [
                'per_tx_cents' => (int) $this->per_tx_limit_usd_cents,
                'daily_cents' => (int) $this->daily_limit_usd_cents,
            ],
            'created_at' => $this->created_at?->toIso8601ZuluString(),
        ];
    }
}
