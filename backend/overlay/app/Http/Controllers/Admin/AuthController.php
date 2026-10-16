<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Staff;
use App\Support\ApiError;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/**
 * Staff sign-in for admin.sarifio.com. Milestone 4 adds TOTP MFA
 * (mfa_secret is already stored encrypted) before a token is issued.
 */
class AuthController extends Controller
{
    public function login(Request $request): JsonResponse
    {
        $data = $request->validate(['email' => ['required', 'email'], 'password' => ['required', 'string']]);
        $staff = Staff::query()->where('email', $data['email'])->where('active', true)->first();
        if (! $staff || ! Hash::check($data['password'], $staff->password)) {
            throw ApiError::make('invalid_credentials', 'Email or password is incorrect.', 401);
        }
        AuditLog::record($staff, 'staff.login', $staff);

        return response()->json([
            'token' => $staff->createToken('admin', ['admin'], now()->addHours(12))->plainTextToken,
            'staff' => ['name' => $staff->name, 'role' => $staff->role, 'permissions' => Staff::PERMISSIONS[$staff->role] ?? []],
        ]);
    }
}
