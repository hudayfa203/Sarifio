<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProviderLog extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['provider_id', 'level', 'event', 'message', 'context'];

    protected function casts(): array
    {
        return ['context' => 'array'];
    }
}
