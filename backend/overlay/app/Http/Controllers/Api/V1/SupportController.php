<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SupportTicket;
use App\Models\Transaction;
use App\Support\Ids;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupportController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $tickets = SupportTicket::query()->where('user_id', $request->user()->id)->latest('id')->limit(50)->get();

        return response()->json(['data' => $tickets->map->toApi()->values()]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'subject' => ['required', 'string', 'min:3', 'max:160'],
            'message' => ['required', 'string', 'min:5', 'max:5000'],
            'transaction_id' => ['nullable', 'string', 'max:40'],
        ]);
        $txId = null;
        if (! empty($data['transaction_id'])) {
            $txId = Transaction::query()->where(['public_id' => $data['transaction_id'], 'user_id' => $request->user()->id])->value('id');
        }
        $ticket = DB::transaction(function () use ($request, $data, $txId) {
            $next = (int) (SupportTicket::query()->lockForUpdate()->max('id') ?? 0) + 10021;

            return SupportTicket::query()->create([
                'public_id' => Ids::make('tkt_'),
                'number' => 'T-'.$next,
                'user_id' => $request->user()->id,
                'transaction_id' => $txId,
                'subject' => $data['subject'],
                'message' => $data['message'],
                'priority' => $txId ? 'high' : 'normal',
            ]);
        });

        return response()->json($ticket->toApi(), 201);
    }
}
