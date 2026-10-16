<?php

namespace App\Http\Controllers\Admin;

use App\Domain\Ledger\Ledger;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Reporting seed for Milestone 4: volume and fee revenue by provider, route
 * and currency, plus trial balance. Test and live data are reported apart.
 * Fee revenue counts settled exchanges only.
 */
class ReportController extends Controller
{
    public function summary(Request $request): JsonResponse
    {
        $data = $request->validate([
            'from' => ['required', 'date'],
            'to' => ['required', 'date', 'after_or_equal:from'],
            'livemode' => ['sometimes', 'boolean'],
        ]);
        $live = (bool) ($data['livemode'] ?? (config('sarifio.mode') === 'production'));
        $base = DB::table('transactions as t')
            ->join('providers as pf', 'pf.id', '=', 't.from_provider_id')
            ->join('providers as pt', 'pt.id', '=', 't.to_provider_id')
            ->where('t.livemode', $live)
            ->whereBetween('t.created_at', [$data['from'], $data['to'].' 23:59:59']);

        $byStatus = (clone $base)->groupBy('t.status')->selectRaw('t.status, COUNT(*) as count')->pluck('count', 'status');
        $byRoute = (clone $base)->where('t.status', 'settled')
            ->groupBy('pf.code', 'pt.code', 't.currency', 't.receive_currency')
            ->selectRaw('pf.code as from_code, pt.code as to_code, t.currency, t.receive_currency, COUNT(*) as count,
                SUM(t.amount_minor) as volume_minor, SUM(t.fee_minor) as fee_revenue_minor,
                SUM(t.provider_fee_minor) as provider_fees_minor, SUM(t.rate_difference_minor) as fx_spread_minor')
            ->get();
        $byProvider = (clone $base)->where('t.status', 'settled')
            ->groupBy('pf.code', 't.currency')
            ->selectRaw('pf.code as provider, t.currency, COUNT(*) as count, SUM(t.amount_minor) as volume_minor, SUM(t.fee_minor) as fee_revenue_minor')
            ->get();

        return response()->json([
            'livemode' => $live,
            'by_status' => $byStatus,
            'by_route' => $byRoute,
            'by_provider' => $byProvider,
        ]);
    }

    public function trialBalance(Request $request, Ledger $ledger): JsonResponse
    {
        $data = $request->validate([
            'currency' => ['required', 'in:'.implode(',', array_keys(config('sarifio.currencies')))],
            'livemode' => ['sometimes', 'boolean'],
        ]);
        $live = (bool) ($data['livemode'] ?? (config('sarifio.mode') === 'production'));
        $rows = $ledger->trialBalance($data['currency'], $live);

        return response()->json([
            'currency' => $data['currency'],
            'livemode' => $live,
            'accounts' => $rows,
            'total_debit_minor' => array_sum(array_column($rows, 'debit_minor')),
            'total_credit_minor' => array_sum(array_column($rows, 'credit_minor')),
        ]);
    }
}
