<?php

namespace Tests\Unit;

use App\Domain\Money\FeeEngine;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

class FeeEngineTest extends TestCase
{
    public static function briefTable(): array
    {
        // amount (cents) => [fee, net]   — the official 1% table
        return [
            '$10' => [1000, 10, 990],
            '$50' => [5000, 50, 4950],
            '$100' => [10000, 100, 9900],
            '$500' => [50000, 500, 49500],
            '$1,000' => [100000, 1000, 99000],
            '$5,000' => [500000, 5000, 495000],
        ];
    }

    #[DataProvider('briefTable')]
    public function test_one_percent_fee(int $amount, int $fee, int $net): void
    {
        $q = FeeEngine::quote($amount, 100);
        $this->assertSame($fee, $q['fee_minor']);
        $this->assertSame($net, $q['receive_minor']);
        $this->assertSame(0, $q['rate_difference_minor']);
    }

    public function test_rounding_is_half_up(): void
    {
        $this->assertSame(2, FeeEngine::feeMinor(150, 100));
        $this->assertSame(1, FeeEngine::feeMinor(149, 100));
        $this->assertSame(0, FeeEngine::feeMinor(0, 100));
    }

    public function test_usd_to_etb_lines_are_separate(): void
    {
        $q = FeeEngine::quote(10000, 100, 0, 125000000, 50);
        $this->assertSame(100, $q['fee_minor']);
        $this->assertSame(9900, $q['net_minor']);
        $this->assertSame(124375000, $q['rate_micro']);
        $this->assertSame(1231313, $q['receive_minor']);
        $this->assertSame(6187, $q['rate_difference_minor']);
    }

    public function test_provider_fee_is_its_own_line(): void
    {
        $q = FeeEngine::quote(10000, 100, 50, 129000000, 50); // USD → KES with 0.5% provider charge
        $this->assertSame(100, $q['fee_minor']);
        $this->assertSame(50, $q['provider_fee_minor']);
        $this->assertSame(9850, $q['net_minor']);
    }
}
