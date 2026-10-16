<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class LedgerAccount extends Model
{
    protected $fillable = ['code', 'name', 'type', 'currency', 'livemode', 'provider_id'];

    protected function casts(): array
    {
        return ['livemode' => 'boolean'];
    }
}
