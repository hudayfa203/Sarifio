<?php

use App\Http\Controllers\Admin;
use App\Http\Controllers\Api\V1;
use App\Http\Controllers\Webhooks\ProviderWebhookController;
use Illuminate\Support\Facades\Route;

// ---------------------------------------------------------------- customer API
Route::prefix('v1')->group(function () {
    Route::get('config', [V1\ConfigController::class, 'index']);

    Route::middleware('throttle:otp')->group(function () {
        Route::post('auth/otp/request', [V1\AuthController::class, 'requestOtp']);
        Route::post('auth/otp/verify', [V1\AuthController::class, 'verifyOtp']);
    });

    Route::middleware(['auth:sanctum', 'abilities:customer', 'throttle:api'])->group(function () {
        Route::post('auth/logout', [V1\AuthController::class, 'logout']);
        Route::get('me', [V1\MeController::class, 'show']);
        Route::patch('me', [V1\MeController::class, 'update']);

        Route::post('quotes', [V1\QuoteController::class, 'store'])->middleware('throttle:money');
        Route::get('exchanges', [V1\ExchangeController::class, 'index']);
        Route::get('exchanges/{id}', [V1\ExchangeController::class, 'show']);
        Route::post('exchanges', [V1\ExchangeController::class, 'store'])->middleware('throttle:money');

        Route::get('support/tickets', [V1\SupportController::class, 'index']);
        Route::post('support/tickets', [V1\SupportController::class, 'store']);

        if (config('sarifio.mode') !== 'production') {
            Route::post('sandbox/next-outcome', [V1\SandboxController::class, 'nextOutcome']);
        }
    });
});

// ---------------------------------------------------------------- provider webhooks
Route::post('webhooks/{provider}', ProviderWebhookController::class)->middleware('throttle:webhooks');

// ---------------------------------------------------------------- admin API (admin.sarifio.com)
Route::prefix('admin')->group(function () {
    Route::post('login', [Admin\AuthController::class, 'login'])->middleware('throttle:otp');

    Route::middleware(['auth:sanctum'])->group(function () {
        // API Integration Manager
        Route::get('providers', [Admin\ProviderController::class, 'index'])->middleware('staff:providers.view');
        Route::post('providers', [Admin\ProviderController::class, 'store'])->middleware('staff:providers.configure');
        Route::get('providers/{provider:code}', [Admin\ProviderController::class, 'show'])->middleware('staff:providers.view');
        Route::patch('providers/{provider:code}', [Admin\ProviderController::class, 'update'])->middleware('staff:providers.configure');
        Route::put('providers/{provider:code}/credentials', [Admin\ProviderController::class, 'storeCredentials'])->middleware('staff:providers.configure');
        Route::post('providers/{provider:code}/test', [Admin\ProviderController::class, 'test'])->middleware('staff:providers.configure');
        Route::put('providers/{provider:code}/approvals', [Admin\ProviderController::class, 'approvals'])->middleware('staff:kyc.manage');
        Route::put('providers/{provider:code}/status', [Admin\ProviderController::class, 'status'])->middleware('staff:providers.configure');

        // Exchange management
        Route::get('routes', [Admin\ExchangeManagementController::class, 'routes'])->middleware('staff:providers.view');
        Route::put('routes', [Admin\ExchangeManagementController::class, 'upsertRoute'])->middleware('staff:routes.manage');
        Route::get('rates', [Admin\ExchangeManagementController::class, 'rates'])->middleware('staff:providers.view');
        Route::put('rates', [Admin\ExchangeManagementController::class, 'upsertRate'])->middleware('staff:rates.manage');
        Route::get('fee', [Admin\ExchangeManagementController::class, 'fee'])->middleware('staff:reports.view');
        Route::put('fee', [Admin\ExchangeManagementController::class, 'updateFee'])->middleware('staff:fees.manage');

        // Reports & accounting
        Route::get('reports/summary', [Admin\ReportController::class, 'summary'])->middleware('staff:reports.view');
        Route::get('reports/trial-balance', [Admin\ReportController::class, 'trialBalance'])->middleware('staff:ledger.view');

        // Company profile (CMS core)
        Route::get('settings/company', [Admin\SettingsController::class, 'company'])->middleware('staff:cms.manage');
        Route::put('settings/company', [Admin\SettingsController::class, 'updateCompany'])->middleware('staff:cms.manage');
    });
});
