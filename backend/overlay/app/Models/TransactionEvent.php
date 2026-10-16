<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class TransactionEvent extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['transaction_id', 'status', 'note'];

    protected function casts(): array
    {
        return ['created_at' => 'datetime'];
    }
}
