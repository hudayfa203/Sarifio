<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Exchange\ExchangeService;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class QuoteController extends Controller
{
    public function store(Request $request, ExchangeService $exchanges): JsonResponse
    {
        $data = $request->validate([
            'from' => ['required', 'string', 'max:40'],
            'to' => ['required', 'string', 'max:40', 'different:from'],
            'amount_minor' => ['required_without:amount_cents', 'integer', 'min:1', 'max:100000000000'],
            'amount_cents' => ['required_without:amount_minor', 'integer', 'min:1', 'max:100000000000'], // legacy USD clients
        ]);
        $amount = (int) ($data['amount_minor'] ?? $data['amount_cents']);
        $quote = $exchanges->quote($request->user(), $data['from'], $data['to'], $amount);

        return response()->json($quote->load(['from', 'to'])->toApi(), 201);
    }
}
