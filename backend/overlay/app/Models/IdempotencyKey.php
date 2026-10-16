<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class IdempotencyKey extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['user_id', 'key', 'request_hash', 'response_status', 'response_body', 'transaction_id'];

    protected function casts(): array
    {
        return ['response_body' => 'array'];
    }
}
