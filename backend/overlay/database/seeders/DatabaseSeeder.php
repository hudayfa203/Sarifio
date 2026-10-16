<?php

namespace Database\Seeders;

use App\Models\ExchangeRoute;
use App\Models\FxRate;
use App\Models\Provider;
use App\Models\Setting;
use App\Models\Staff;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        Setting::query()->updateOrCreate(['key' => 'company'], ['value' => config('sarifio.company_defaults')]);
        Setting::query()->updateOrCreate(['key' => 'app_announcements'], ['value' => [[
            'id' => 'welcome',
            'title' => ['en' => 'You are in Test Mode', 'so' => 'Waxaad ku jirtaa Habka Tijaabada'],
            'body' => [
                'en' => 'Exchanges, exchange rates and provider charges here are simulated. No real money moves.',
                'so' => 'Sarrifyada, sicirrada iyo khidmadaha bixiyeyaasha halkan waa tijaabo. Lacag dhab ah ma dhaqaaqdo.',
            ],
        ]]]);

        $sandbox = config('sarifio.mode') !== 'production';
        // In staging every wallet runs on the simulator ("sandbox"). In production
        // everything starts "not_configured" and goes live only via the checklist.
        $start = $sandbox ? 'sandbox' : 'not_configured';
        $providers = [
            ['sahal', 'Sahal', 'WaafiPay', 'SO', 'USD', 'sahal', $start, true, true, 10],
            ['evc_plus', 'EVC Plus', 'WaafiPay', 'SO', 'USD', 'evc_plus', $start, true, true, 20],
            ['edahab', 'eDahab', null, 'SO', 'USD', 'edahab', $start, true, true, 30],
            ['premier_wallet', 'Premier Wallet', null, 'SO', 'USD', 'premier_wallet', $start, true, true, 40],
            ['ebirr', 'eBirr', null, 'ET', 'ETB', 'ebirr', $start, true, true, 50],
            ['mpesa', 'M-Pesa', null, 'KE', 'KES', 'mpesa', $start, true, true, 60],
            ['binance', 'Binance', null, 'XX', 'USD', 'binance', 'not_configured', false, false, 70],
            ['visa', 'Visa', 'Card processor', 'XX', 'USD', 'visa', 'not_configured', true, false, 80],
        ];
        foreach ($providers as [$code, $name, $group, $country, $currency, $adapter, $status, $collect, $payout, $sort]) {
            Provider::query()->updateOrCreate(['code' => $code], [
                'name' => $name, 'group_name' => $group, 'country' => $country, 'currency' => $currency,
                'adapter_key' => $adapter, 'status' => $status, 'can_collect' => $collect, 'can_payout' => $payout,
                'enabled' => $status !== 'not_configured', 'sort' => $sort,
                'approvals' => ['api_access' => false, 'agreement' => false, 'regulatory' => false],
            ]);
        }

        $somali = ['sahal', 'evc_plus', 'edahab', 'premier_wallet'];
        $pairs = [
            ['sahal', 'edahab'], ['sahal', 'premier_wallet'], ['edahab', 'sahal'], ['premier_wallet', 'sahal'],
            ['evc_plus', 'edahab'], ['evc_plus', 'premier_wallet'], ['edahab', 'evc_plus'], ['premier_wallet', 'evc_plus'],
            ['edahab', 'premier_wallet'], ['premier_wallet', 'edahab'], ['ebirr', 'mpesa'], ['mpesa', 'ebirr'],
        ];
        foreach ($somali as $w) {
            array_push($pairs, [$w, 'ebirr'], ['ebirr', $w], [$w, 'mpesa'], ['mpesa', $w]);
        }
        $id = Provider::query()->pluck('id', 'code');
        foreach ($pairs as [$from, $to]) {
            ExchangeRoute::query()->updateOrCreate(
                ['from_provider_id' => $id[$from], 'to_provider_id' => $id[$to]],
                // Sandbox example of a pass-through provider charge so the app can show that line.
                ['enabled' => $sandbox, 'provider_fee_bps' => ($sandbox && $to === 'mpesa') ? 50 : 0],
            );
        }

        if ($sandbox) {
            // SANDBOX TEST RATES — illustrative only, not market rates.
            // Administrators set real rates in Exchange Management before go-live.
            $rates = [
                ['USD', 'ETB', 125000000], ['ETB', 'USD', 8000],
                ['USD', 'KES', 129000000], ['KES', 'USD', 7750],
                ['ETB', 'KES', 1032000], ['KES', 'ETB', 969000],
            ];
            foreach ($rates as [$from, $to, $micro]) {
                FxRate::query()->updateOrCreate(
                    ['from_currency' => $from, 'to_currency' => $to],
                    ['mid_rate_micro' => $micro, 'spread_bps' => 50, 'source' => 'sandbox-test-rate'],
                );
            }
        }

        if ($email = env('SEED_ADMIN_EMAIL')) {
            Staff::query()->updateOrCreate(['email' => $email], [
                'name' => env('SEED_ADMIN_NAME', 'SARIFIO Admin'),
                'password' => env('SEED_ADMIN_PASSWORD') ?: throw new \RuntimeException('Set SEED_ADMIN_PASSWORD.'),
                'role' => 'super_admin',
            ]);
        }
    }
}
