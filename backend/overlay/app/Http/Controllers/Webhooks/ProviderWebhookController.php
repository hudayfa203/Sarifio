<?php

namespace App\Http\Controllers\Webhooks;

use App\Domain\Exchange\ExchangeService;
use App\Domain\Providers\ProviderRegistry;
use App\Http\Controllers\Controller;
use App\Jobs\ProcessExchange;
use App\Models\Provider;
use App\Models\Transaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * POST /api/webhooks/{provider}. Only signature-verified callbacks from a
 * provider's official adapter can move a transaction forward; replays are
 * harmless because every state change is guarded by the current status.
 */
class ProviderWebhookController extends Controller
{
    public function __invoke(Request $request, string $provider, ProviderRegistry $registry, ExchangeService $exchanges): JsonResponse
    {
        $p = Provider::query()->where('code', $provider)->firstOrFail();
        $env = $registry->environment();
        $secret = $p->credentials()->where('environment', $env)->first()?->webhook_secret;
        $adapter = $registry->official($p);

        if (! $adapter->verifyWebhook($request, $secret)) {
            $p->log('warning', 'webhook.rejected', 'Webhook signature verification failed.', ['ip' => $request->ip()]);

            return response()->json(['error' => ['code' => 'invalid_signature', 'message' => 'Rejected.']], 401);
        }
        $event = $adapter->parseWebhook($request);
        $column = $event['leg'] === 'collection' ? 'collection_ref' : 'payout_ref';

        $next = DB::transaction(function () use ($column, $event, $exchanges) {
            $tx = Transaction::query()->where($column, $event['reference'])->lockForUpdate()->first();
            if (! $tx) {
                return null;
            }
            if ($event['leg'] === 'collection' && $tx->status === 'awaiting_payment') {
                return $exchanges->applyCollectionResult($tx, $event['result']) ? $tx->id : null;
            }
            if ($event['leg'] === 'payout' && $tx->status === 'payout_processing') {
                $exchanges->applyPayoutResult($tx, $event['result']);
            }

            return null;
        });
        if ($next) {
            ProcessExchange::dispatch($next, 'payout');
        }
        $p->log('info', 'webhook.accepted', "{$event['leg']} {$event['reference']}");

        return response()->json(['received' => true]);
    }
}
