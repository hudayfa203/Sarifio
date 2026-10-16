<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Auth\OtpService;
use App\Http\Controllers\Controller;
use App\Models\ExchangeRoute;
use App\Models\FeeSetting;
use App\Models\FxRate;
use App\Models\Provider;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Cache;

/** Everything the apps and website need to render providers, routes, rates, fee and company details. */
class ConfigController extends Controller
{
    public function index(OtpService $otp): JsonResponse
    {
        $body = Cache::remember('public-config', 60, function () use ($otp) {
            $providers = Provider::query()->orderBy('sort')->get();
            $routes = ExchangeRoute::query()->with(['from', 'to'])->get();

            return [
                'environment' => config('sarifio.mode') === 'production' ? 'production' : 'staging',
                'test_mode' => config('sarifio.mode') !== 'production',
                'company' => Setting::get('company', config('sarifio.company_defaults')),
                'fee' => ['bps' => FeeSetting::currentBps()],
                'currencies' => collect(config('sarifio.currencies'))->map(fn ($c, $code) => ['code' => $code] + $c)->values(),
                'providers' => $providers->map(fn (Provider $p) => $p->toApi() + ['website_status' => $p->websiteStatus()])->values(),
                'routes' => $routes->map(fn (ExchangeRoute $r) => [
                    'from' => $r->from->code,
                    'to' => $r->to->code,
                    'enabled' => $r->available(),
                    'provider_fee_bps' => (int) $r->provider_fee_bps,
                ])->values(),
                'rates' => FxRate::query()->get()->map(fn (FxRate $r) => [
                    'from' => $r->from_currency,
                    'to' => $r->to_currency,
                    'mid_rate_micro' => (int) $r->mid_rate_micro,
                    'spread_bps' => (int) $r->spread_bps,
                    'updated_at' => $r->updated_at?->toIso8601ZuluString(),
                ])->values(),
                'announcements' => Setting::get('app_announcements', []),
                'otp_channels' => $otp->channels(null),
            ];
        });

        return response()->json($body);
    }
}
