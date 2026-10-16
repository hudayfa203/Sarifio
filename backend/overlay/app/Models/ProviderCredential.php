<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** Encrypted at rest (APP_KEY). Never serialised to any client. */
class ProviderCredential extends Model
{
    protected $fillable = ['provider_id', 'environment', 'values', 'webhook_secret', 'configured_by'];

    protected $hidden = ['values', 'webhook_secret'];

    protected function casts(): array
    {
        return ['values' => 'encrypted:array', 'webhook_secret' => 'encrypted'];
    }

    public function provider(): BelongsTo
    {
        return $this->belongsTo(Provider::class);
    }
}
