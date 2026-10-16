<?php

namespace App\Support;

final class Ids
{
    private const ALPHABET = 'ABCDEFGHJKMNPQRSTVWXYZ0123456789';

    /** Prefixed public id, e.g. tx_7Q2K91XD4M. Internal numeric ids never leave the API. */
    public static function make(string $prefix, int $length = 16): string
    {
        $out = '';
        for ($i = 0; $i < $length; $i++) {
            $out .= self::ALPHABET[random_int(0, strlen(self::ALPHABET) - 1)];
        }

        return $prefix.$out;
    }

    /** Human-readable transaction reference: SRF-7Q2K-91XD (test refs carry a T). */
    public static function reference(bool $livemode): string
    {
        $a = substr(self::make('', 4), 0, 4);
        $b = substr(self::make('', 4), 0, 4);

        return 'SRF-'.($livemode ? '' : 'T').$a.'-'.$b;
    }

    public static function mask(string $account): string
    {
        $digits = preg_replace('/\D/', '', $account) ?? '';

        return '•••• '.substr($digits, -4);
    }
}
