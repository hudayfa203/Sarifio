<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** Admin-configured rate for a currency pair, in micro-units. */
class FxRate extends Model
{
    protected $fillable = ['from_currency', 'to_currency', 'mid_rate_micro', 'spread_bps', 'source', 'updated_by'];

    /** Returns [mid_rate_micro, spread_bps] or null when the pair has no rate. */
    public static function for(string $from, string $to): ?array
    {
        if ($from === $to) {
            return [1000000, 0];
        }
        $r = static::query()->where('from_currency', $from)->where('to_currency', $to)->first();

        return $r ? [(int) $r->mid_rate_micro, (int) $r->spread_bps] : null;
    }
}
