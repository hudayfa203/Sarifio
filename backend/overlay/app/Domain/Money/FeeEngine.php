<?php

namespace App\Domain\Money;

/**
 * The single fee and FX engine for SARIFIO (apps, website, admin, accounting,
 * receipts). Integer arithmetic only: amounts in minor units, rates in
 * micro-units (1 USD = 125.5 ETB → 125500000). Mirrors mobile/lib/core/money.dart.
 */
final class FeeEngine
{
    public const DEFAULT_FEE_BPS = 100; // 1%

    public static function feeMinor(int $amountMinor, int $bps): int
    {
        if ($amountMinor <= 0 || $bps <= 0) {
            return 0;
        }

        return intdiv($amountMinor * $bps + 5000, 10000); // round half up
    }

    public static function convert(int $minor, int $rateMicro): int
    {
        if ($minor <= 0) {
            return 0;
        }

        return intdiv($minor * $rateMicro + 500000, 1000000);
    }

    public static function appliedRate(int $midRateMicro, int $spreadBps): int
    {
        return intdiv($midRateMicro * (10000 - $spreadBps) + 5000, 10000);
    }

    /**
     * @return array{fee_minor:int, provider_fee_minor:int, net_minor:int, rate_micro:int, receive_minor:int, rate_difference_minor:int}
     */
    public static function quote(
        int $amountMinor,
        int $feeBps,
        int $providerFeeBps = 0,
        int $midRateMicro = 1000000,
        int $spreadBps = 0,
    ): array {
        $fee = self::feeMinor($amountMinor, $feeBps);
        $providerFee = self::feeMinor($amountMinor, $providerFeeBps);
        $net = max(0, $amountMinor - $fee - $providerFee);
        $rate = self::appliedRate($midRateMicro, $spreadBps);
        $receive = self::convert($net, $rate);
        $atMid = self::convert($net, $midRateMicro);

        return [
            'fee_minor' => $fee,
            'provider_fee_minor' => $providerFee,
            'net_minor' => $net,
            'rate_micro' => $rate,
            'receive_minor' => $receive,
            'rate_difference_minor' => $atMid - $receive,
        ];
    }
}
