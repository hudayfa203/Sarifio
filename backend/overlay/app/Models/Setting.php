<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Key/value company settings edited from the admin CMS (company profile, contacts, …). */
class Setting extends Model
{
    protected $primaryKey = 'key';

    public $incrementing = false;

    protected $keyType = 'string';

    protected $fillable = ['key', 'value', 'updated_by'];

    protected function casts(): array
    {
        return ['value' => 'array'];
    }

    public static function get(string $key, array $default = []): array
    {
        return static::query()->find($key)?->value ?? $default;
    }
}
