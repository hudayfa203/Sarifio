<?php

namespace App\Http\Controllers\Api\V1;

use App\Domain\Auth\OtpService;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

class AuthController extends Controller
{
    public function __construct(private OtpService $otp) {}

    public function requestOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => ['required', 'string', 'regex:/^\+[1-9]\d{6,14}$/'],
            'name' => ['nullable', 'string', 'min:2', 'max:120'],
            'purpose' => ['required', 'in:register,login'],
            'channel' => ['sometimes', 'in:sms,whatsapp,email'],
        ]);
        $r = $this->otp->request($data['phone'], $data['name'] ?? null, $data['purpose'], $data['channel'] ?? 'sms', $request->ip());
        $cfg = config('sarifio.otp');
        $body = [
            'request_id' => $r['challenge']->public_id,
            'channel' => $r['challenge']->channel,
            'expires_in' => $cfg['ttl_seconds'],
            'resend_in' => $cfg['resend_after_seconds'],
        ];
        if (config('sarifio.mode') !== 'production' && config('sarifio.otp_reveal')) {
            $body['test_code'] = $r['code']; // staging only, fresh random code per request
        }

        return response()->json($body, 201);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'request_id' => ['required', 'string', 'max:40'],
            'code' => ['required', 'digits:6'],
            'device_name' => ['required', 'string', 'max:80'],
        ]);
        $user = $this->otp->verify($data['request_id'], $data['code']);
        $token = $user->createToken($data['device_name'], ['customer'])->plainTextToken;

        return response()->json(['token' => $token, 'user' => $user->toApi()]);
    }

    public function logout(Request $request): Response
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->noContent();
    }
}
