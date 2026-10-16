<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\ExchangeRoute;
use App\Models\FeeSetting;
use App\Models\FxRate;
use App\Models\Provider;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/** Exchange routes, currency rates (USD/ETB/KES …) and the service fee. */
class ExchangeManagementController extends Controller
{
    public function routes(): JsonResponse
    {
        return response()->json(['data' => ExchangeRoute::query()->with(['from', 'to'])->get()->map(fn (ExchangeRoute $r) => [
            'id' => $r->id,
            'from' => $r->from->code,
            'to' => $r->to->code,
            'from_currency' => $r->from->currency,
            'to_currency' => $r->to->currency,
            'enabled' => $r->enabled,
            'available' => $r->available(),
            'provider_fee_bps' => (int) $r->provider_fee_bps,
            'min_minor' => $r->min_minor,
            'max_minor' => $r->max_minor,
        ])]);
    }

    public function upsertRoute(Request $request): JsonResponse
    {
        $data = $request->validate([
            'from' => ['required', 'exists:providers,code'],
            'to' => ['required', 'exists:providers,code', 'different:from'],
            'enabled' => ['required', 'boolean'],
            'provider_fee_bps' => ['sometimes', 'integer', 'min:0', 'max:1000'],
            'min_minor' => ['nullable', 'integer', 'min:1'],
            'max_minor' => ['nullable', 'integer', 'min:1'],
        ]);
        $from = Provider::query()->where('code', $data['from'])->firstOrFail();
        $to = Provider::query()->where('code', $data['to'])->firstOrFail();
        $route = ExchangeRoute::query()->updateOrCreate(
            ['from_provider_id' => $from->id, 'to_provider_id' => $to->id],
            collect($data)->except(['from', 'to'])->all(),
        );
        AuditLog::record($request->user(), 'route.saved', $route, null, $data);
        Cache::forget('public-config');

        return response()->json(['id' => $route->id, 'available' => $route->available()]);
    }

    public function rates(): JsonResponse
    {
        return response()->json(['data' => FxRate::query()->orderBy('from_currency')->get()]);
    }

    public function upsertRate(Request $request): JsonResponse
    {
        $codes = array_keys(config('sarifio.currencies'));
        $data = $request->validate([
            'from_currency' => ['required', Rule::in($codes)],
            'to_currency' => ['required', Rule::in($codes), 'different:from_currency'],
            'mid_rate_micro' => ['required', 'integer', 'min:1'],
            'spread_bps' => ['required', 'integer', 'min:0', 'max:2000'],
            'source' => ['nullable', 'string', 'max:60'],
        ]);
        $rate = DB::transaction(function () use ($data, $request) {
            $rate = FxRate::query()->updateOrCreate(
                ['from_currency' => $data['from_currency'], 'to_currency' => $data['to_currency']],
                $data + ['updated_by' => $request->user()->id],
            );
            DB::table('fx_rate_history')->insert([
                'from_currency' => $data['from_currency'], 'to_currency' => $data['to_currency'],
                'mid_rate_micro' => $data['mid_rate_micro'], 'spread_bps' => $data['spread_bps'],
                'changed_by' => $request->user()->id, 'created_at' => now(),
            ]);

            return $rate;
        });
        AuditLog::record($request->user(), 'rate.saved', $rate, null, $data);
        Cache::forget('public-config');

        return response()->json($rate);
    }

    public function fee(): JsonResponse
    {
        return response()->json([
            'fee_bps' => FeeSetting::currentBps(),
            'history' => FeeSetting::query()->latest('id')->limit(20)->get(),
        ]);
    }

    /** Only finance managers / super admins; every change is audited. Applies to new quotes only. */
    public function updateFee(Request $request): JsonResponse
    {
        $data = $request->validate([
            'fee_bps' => ['required', 'integer', 'min:0', 'max:1000'],
            'reason' => ['required', 'string', 'min:5', 'max:255'],
        ]);
        $before = FeeSetting::currentBps();
        FeeSetting::query()->create($data + ['changed_by' => $request->user()->id]);
        AuditLog::record($request->user(), 'fee.changed', null, ['fee_bps' => $before], $data);
        Cache::forget('public-config');

        return response()->json(['fee_bps' => $data['fee_bps']]);
    }
}
