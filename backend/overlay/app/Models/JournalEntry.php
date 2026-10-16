<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class JournalEntry extends Model
{
    protected $fillable = ['public_id', 'transaction_id', 'kind', 'description', 'currency', 'livemode', 'posted_at', 'created_by'];

    protected function casts(): array
    {
        return ['livemode' => 'boolean', 'posted_at' => 'datetime'];
    }

    public function lines(): HasMany
    {
        return $this->hasMany(JournalLine::class);
    }
}
