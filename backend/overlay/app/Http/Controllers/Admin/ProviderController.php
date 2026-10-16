<?php

namespace App\Http\Controllers\Admin;

use App\Domain\Providers\ProviderRegistry;
use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Provider;
use App\Support\ApiError;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\Rule;

/**
 * API Integration Manager: one section per provider (WaafiPay/Sahal/EVC Plus,
 * eDahab, Premier Wallet, eBirr, M-Pesa, Binance, card processor, and any
 * future provider). Credentials are write-only: responses only say which
 * fields are set, never their values.
 */
class ProviderController extends Controller
{
    public function __construct(private ProviderRegistry $registry) {}

    private function present(Provider $p): array
    {
        $adapter = $this->registry->official($p);
        $creds = $p->credentials()->get()->keyBy('environment');

        return $p->toApi() + [
            'id' => $p->id,
            'enabled' => $p->enabled,
            'adapter_key' => $p->adapter_key,
            'display' => $p->display,
            'limits' => $p->limits,
            'approvals' => $p->approvals ?? ['api_access' => false, 'agreement' => false, 'regulatory' => false],
            'docs_url' => $adapter->docsUrl(),
            'credential_fields' => $adapter->credentialFields(),
            'credentials' => collect(['sandbox', 'production'])->mapWithKeys(fn ($env) => [$env => [
                'configured' => $creds->has($env),
                'fields_set' => array_keys(array_filter($creds->get($env)?->values ?? [], fn ($v) => filled($v))),
                'updated_at' => $creds->get($env)?->updated_at?->toIso8601ZuluString(),
            ]]),
            'last_test' => ['at' => $p->last_test_at?->toIso8601ZuluString(), 'ok' => $p->last_test_ok, 'message' => $p->last_test_message],
            'go_live_blockers' => $p->goLiveBlockers(),
            'website_status' => $p->websiteStatus(),
        ];
    }

    public function index(): JsonResponse
    {
        return response()->json(['data' => Provider::query()->orderBy('sort')->get()->map(fn ($p) => $this->present($p))]);
    }

    public function show(Provider $provider): JsonResponse
    {
        return response()->json($this->present($provider) + [
            'logs' => $provider->logs()->latest('id')->limit(50)->get(['level', 'event', 'message', 'created_at']),
        ]);
    }

    /** Create a new provider row for a registered adapter (future wallets). */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'code' => ['required', 'alpha_dash', 'max:40', 'unique:providers,code'],
            'name' => ['required', 'string', 'max:80'],
            'group_name' => ['nullable', 'string', 'max:80'],
            'country' => ['required', 'string', 'size:2'],
            'currency' => ['required', 'string', 'size:3', Rule::in(array_keys(config('sarifio.currencies')))],
            'adapter_key' => ['required', Rule::in(array_keys(config('sarifio.providers')))],
        ]);
        $p = Provider::query()->create($data + ['status' => 'not_configured', 'enabled' => false]);
        AuditLog::record($request->user(), 'provider.created', $p, null, $data);
        Cache::forget('public-config');

        return response()->json($this->present($p), 201);
    }

    public function update(Request $request, Provider $provider): JsonResponse
    {
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'max:80'],
            'enabled' => ['sometimes', 'boolean'],
            'can_collect' => ['sometimes', 'boolean'],
            'can_payout' => ['sometimes', 'boolean'],
            'sort' => ['sometimes', 'integer', 'min:0'],
            'display' => ['sometimes', 'array'],
            'limits' => ['sometimes', 'array'],
        ]);
        $before = $provider->only(array_keys($data));
        $provider->update($data);
        AuditLog::record($request->user(), 'provider.updated', $provider, $before, $data);
        Cache::forget('public-config');

        return response()->json($this->present($provider->fresh()));
    }

    public function storeCredentials(Request $request, Provider $provider): JsonResponse
    {
        $env = $request->validate(['environment' => ['required', 'in:sandbox,production']])['environment'];
        $fields = collect($this->registry->official($provider)->credentialFields())->keyBy('key');
        $values = $request->validate(['values' => ['required', 'array']])['values'];
        $values = array_intersect_key($values, $fields->all());

        $existing = $provider->credentials()->where('environment', $env)->first();
        // Blank secret fields keep their previous value, so admins never have to re-type them.
        $merged = array_merge($existing?->values ?? [], array_filter($values, fn ($v) => filled($v)));
        $provider->credentials()->updateOrCreate(['environment' => $env], [
            'values' => $merged,
            'webhook_secret' => $merged['webhook_secret'] ?? $existing?->webhook_secret,
            'configured_by' => $request->user()->id,
        ]);
        if ($provider->status === 'not_configured' && $env === 'sandbox') {
            $provider->update(['status' => 'testing']);
        }
        $provider->update(['last_test_ok' => null, 'last_test_message' => 'Credentials changed — run the connection test again.']);
        $provider->log('info', 'credentials.updated', "{$env} credentials updated", ['fields' => array_keys($values)]);
        AuditLog::record($request->user(), 'provider.credentials_updated', $provider, null, ['environment' => $env, 'fields' => array_keys($values)]);

        return response()->json($this->present($provider->fresh()));
    }

    public function test(Request $request, Provider $provider): JsonResponse
    {
        $env = $request->validate(['environment' => ['required', 'in:sandbox,production']])['environment'];
        $result = $this->registry->official($provider)->testConnection($this->registry->credentials($provider, $env), $env);
        $provider->update(['last_test_at' => now(), 'last_test_ok' => $result->succeeded(), 'last_test_message' => $result->message]);
        $provider->log($result->succeeded() ? 'info' : 'error', 'connection.test', "[{$env}] {$result->message}");
        AuditLog::record($request->user(), 'provider.tested', $provider, null, ['environment' => $env, 'ok' => $result->succeeded()]);

        return response()->json(['ok' => $result->succeeded(), 'message' => $result->message, 'provider' => $this->present($provider->fresh())]);
    }

    /** Record official API access / agreement / regulatory approval (super admin, compliance). */
    public function approvals(Request $request, Provider $provider): JsonResponse
    {
        $data = $request->validate([
            'api_access' => ['required', 'boolean'],
            'agreement' => ['required', 'boolean'],
            'regulatory' => ['required', 'boolean'],
            'evidence' => ['nullable', 'string', 'max:500'],
        ]);
        $before = $provider->approvals;
        $provider->update(['approvals' => $data + ['approved_by' => $request->user()->id, 'approved_at' => now()->toIso8601ZuluString()]]);
        AuditLog::record($request->user(), 'provider.approvals', $provider, $before, $provider->approvals);

        return response()->json($this->present($provider->fresh()));
    }

    public function status(Request $request, Provider $provider): JsonResponse
    {
        $status = $request->validate(['status' => ['required', Rule::in(Provider::STATUSES)]])['status'];
        if ($status === 'live') {
            if ($blockers = $provider->goLiveBlockers()) {
                throw ApiError::make('go_live_blocked', implode(' ', $blockers), 422);
            }
            // Four-eyes: the person who recorded approvals cannot also switch the provider live.
            if (($provider->approvals['approved_by'] ?? null) === $request->user()->id) {
                throw ApiError::make('go_live_blocked', 'A second administrator must switch this provider live.', 422);
            }
        }
        $before = $provider->status;
        $provider->update(['status' => $status]);
        $provider->log('warning', 'status.changed', "Status {$before} → {$status}");
        AuditLog::record($request->user(), 'provider.status', $provider, ['status' => $before], ['status' => $status]);
        Cache::forget('public-config');

        return response()->json($this->present($provider->fresh()));
    }
}
