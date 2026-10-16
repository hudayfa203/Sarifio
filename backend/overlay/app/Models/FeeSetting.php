<?php

namespace App\Models;

use App\Domain\Money\FeeEngine;
use Illuminate\Database\Eloquent\Model;

/** Fee history. The newest row is the active fee; the default is 1%. */
class FeeSetting extends Model
{
    protected $fillable = ['fee_bps', 'changed_by', 'reason'];

    public static function currentBps(): int
    {
        $row = static::query()->latest('id')->first();

        return $row ? (int) $row->fee_bps : (int) config('sarifio.default_fee_bps', FeeEngine::DEFAULT_FEE_BPS);
    }
}
