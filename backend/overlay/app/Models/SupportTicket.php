<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class SupportTicket extends Model
{
    protected $fillable = ['public_id', 'number', 'user_id', 'transaction_id', 'subject', 'message', 'status', 'priority', 'assigned_to'];

    public function toApi(): array
    {
        return [
            'id' => $this->public_id,
            'number' => $this->number,
            'subject' => $this->subject,
            'status' => $this->status,
            'created_at' => $this->created_at->toIso8601ZuluString(),
        ];
    }
}
