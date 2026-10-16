<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AuditLog extends Model
{
    public const UPDATED_AT = null;

    protected $fillable = ['actor_id', 'action', 'subject_type', 'subject_id', 'before', 'after', 'ip'];

    protected function casts(): array
    {
        return ['before' => 'array', 'after' => 'array'];
    }

    public static function record(?Staff $actor, string $action, ?Model $subject = null, ?array $before = null, ?array $after = null): void
    {
        static::query()->create([
            'actor_id' => $actor?->id,
            'action' => $action,
            'subject_type' => $subject ? class_basename($subject) : null,
            'subject_id' => $subject?->getKey() !== null ? (string) $subject->getKey() : null,
            'before' => $before,
            'after' => $after,
            'ip' => request()?->ip(),
        ]);
    }
}
