<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/** Staging-only Test Mode controls. Routes are not registered in production. */
class SandboxController extends Controller
{
    public function nextOutcome(Request $request): Response
    {
        $data = $request->validate(['outcome' => ['required', 'in:success,fail_payment,fail_payout,manual_review']]);
        $request->user()->update(['sandbox_next_outcome' => $data['outcome']]);

        return response()->noContent();
    }
}
