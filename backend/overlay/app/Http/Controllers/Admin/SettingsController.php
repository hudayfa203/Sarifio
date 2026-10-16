<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;

/** Company profile used by apps, website, notifications and receipts (CMS core). */
class SettingsController extends Controller
{
    public function company(): JsonResponse
    {
        return response()->json(Setting::get('company', config('sarifio.company_defaults')));
    }

    public function updateCompany(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:80'],
            'tagline' => ['required', 'string', 'max:120'],
            'website' => ['required', 'string', 'max:120'],
            'email' => ['required', 'email'],
            'support_email' => ['required', 'email'],
            'phone' => ['required', 'string', 'regex:/^\+[1-9]\d{6,14}$/'],
            'whatsapp' => ['required', 'string', 'regex:/^\+[1-9]\d{6,14}$/'],
        ]);
        $before = Setting::get('company', config('sarifio.company_defaults'));
        Setting::query()->updateOrCreate(['key' => 'company'], ['value' => $data, 'updated_by' => $request->user()->id]);
        AuditLog::record($request->user(), 'settings.company', null, $before, $data);
        Cache::forget('public-config');

        return response()->json($data);
    }
}
