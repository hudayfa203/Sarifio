<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * A payment provider / wallet (Sahal, EVC Plus, eDahab, Premier Wallet,
 * eBirr, M-Pesa, Binance, card processor, and any future provider).
 */
class Provider extends Model
{
    public const STATUSES = ['not_configured', 'sandbox', 'testing', 'awaiting_approval', 'live', 'disabled', 'error'];

    /** Statuses in which a provider may carry customer exchanges in the current mode. */
    public const USABLE_IN_SANDBOX = ['sandbox', 'testing'];

    protected $fillable = [
        'code', 'name', 'group_name', 'country', 'currency', 'adapter_key', 'status',
        'can_collect', 'can_payout', 'enabled', 'sort', 'display', 'limits', 'approvals',
        'last_test_at', 'last_test_ok', 'last_test_message',
    ];

    protected function casts(): array
    {
        return [
            'can_collect' => 'boolean',
            'can_payout' => 'boolean',
            'enabled' => 'boolean',
            'display' => 'array',
            'limits' => 'array',
            'approvals' => 'array',
            'last_test_at' => 'datetime',
            'last_test_ok' => 'boolean',
        ];
    }

    public function credentials(): HasMany
    {
        return $this->hasMany(ProviderCredential::class);
    }

    public function logs(): HasMany
    {
        return $this->hasMany(ProviderLog::class);
    }

    public function usable(): bool
    {
        if (! $this->enabled) {
            return false;
        }

        return config('sarifio.mode') === 'production'
            ? $this->status === 'live'
            : in_array($this->status, self::USABLE_IN_SANDBOX, true);
    }

    /**
     * Reasons this provider cannot be switched to "live". Empty = allowed.
     * A provider is NEVER live until official API access, the provider
     * agreement and regulatory approval are all recorded, production
     * credentials exist and a production connection test has passed.
     *
     * @return list<string>
     */
    public function goLiveBlockers(): array
    {
        $a = $this->approvals ?? [];
        $blockers = [];
        if (config('sarifio.mode') !== 'production') {
            $blockers[] = 'The platform is not running in production mode.';
        }
        if (empty($a['api_access'])) {
            $blockers[] = 'Official API access has not been recorded.';
        }
        if (empty($a['agreement'])) {
            $blockers[] = 'The provider agreement has not been recorded.';
        }
        if (empty($a['regulatory'])) {
            $blockers[] = 'Regulatory approval has not been recorded.';
        }
        if (! $this->credentials()->where('environment', 'production')->exists()) {
            $blockers[] = 'Production credentials are not configured.';
        }
        if ($this->last_test_ok !== true) {
            $blockers[] = 'The last connection test did not pass.';
        }

        return $blockers;
    }

    public function log(string $level, string $event, string $message, array $context = []): void
    {
        $this->logs()->create(compact('level', 'event', 'message', 'context'));
    }

    /** Public shape for GET /config (no credentials, no approvals). */
    public function toApi(): array
    {
        $status = $this->enabled ? $this->status : 'disabled';

        return [
            'code' => $this->code,
            'name' => $this->name,
            'group' => $this->group_name,
            'country' => $this->country,
            'currency' => $this->currency,
            'status' => $status,
            'can_collect' => $this->can_collect,
            'can_payout' => $this->can_payout,
        ];
    }

    /** Website/app label controlled by status: available | coming_soon | temporarily_unavailable. */
    public function websiteStatus(): string
    {
        if ($this->usable()) {
            return config('sarifio.mode') === 'production' ? 'available' : 'available_in_test_mode';
        }

        return in_array($this->status, ['disabled', 'error'], true) ? 'temporarily_unavailable' : 'coming_soon';
    }
}
