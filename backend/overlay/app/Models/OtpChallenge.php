<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OtpChallenge extends Model
{
    protected $fillable = ['public_id', 'phone', 'name', 'purpose', 'channel', 'code_hash', 'attempts', 'expires_at', 'consumed_at', 'ip'];

    protected $hidden = ['code_hash'];

    protected function casts(): array
    {
        return ['expires_at' => 'datetime', 'consumed_at' => 'datetime'];
    }
}
