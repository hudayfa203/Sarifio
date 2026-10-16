<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Exchange\ExchangeService;
use App\Http\Controllers\Controller;
use App\Models\Transaction;
use App\Support\ApiError;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ExchangeController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $q = $request->user()->transactions()->with(['from', 'to', 'events'])->latest('id');
        if ($status = $request->query('status')) {
            $q->where('status', $status);
        }
        $page = $q->cursorPaginate(30);

        return response()->json([
            'data' => collect($page->items())->map(fn (Transaction $t) => $t->toApi())->values(),
            'next_cursor' => $page->nextCursor()?->encode(),
        ]);
    }

    public function show(Request $request, string $id): JsonResponse
    {
        $tx = $request->user()->transactions()->with(['from', 'to', 'events'])->where('public_id', $id)->first();
        if (! $tx) {
            throw ApiError::make('not_found', 'Transaction not found.', 404);
        }

        return response()->json($tx->toApi());
    }

    public function store(Request $request, ExchangeService $exchanges): JsonResponse
    {
        $key = (string) $request->header('Idempotency-Key', '');
        if (! preg_match('/^[A-Za-z0-9-]{16,64}$/', $key)) {
            throw ApiError::make('validation_failed', 'An Idempotency-Key header is required.', 422);
        }
        $data = $request->validate([
            'quote_id' => ['required', 'string', 'max:40'],
            'recipient_account' => ['required', 'string', 'max:32'],
            'recipient_name' => ['nullable', 'string', 'max:120'],
        ]);
        $tx = $exchanges->create($request->user(), $key, $data['quote_id'], $data['recipient_account'], $data['recipient_name'] ?? null);

        return response()->json($tx->toApi(), 201);
    }
}
