<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class MeController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json($request->user()->toApi());
    }

    public function update(Request $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->validate([
            'name' => ['sometimes', 'string', 'min:2', 'max:120'],
            'email' => ['sometimes', 'nullable', 'email', 'max:190', Rule::unique('users', 'email')->ignore($user->id)],
            'language' => ['sometimes', 'in:en,so'],
        ]);
        if (array_key_exists('email', $data) && $data['email'] !== $user->email) {
            $user->email_verified_at = null; // must be re-verified before email OTP is offered
        }
        $user->fill($data)->save();

        return response()->json($user->toApi());
    }
}
