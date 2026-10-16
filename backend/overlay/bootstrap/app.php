<?php

use App\Http\Middleware\StaffPermission;
use App\Support\ApiError;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\ThrottleRequestsException;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Laravel\Sanctum\Http\Middleware\CheckAbilities;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->alias([
            'abilities' => CheckAbilities::class,
            'staff' => StaffPermission::class,
        ]);
        $middleware->trustProxies(at: '*');
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $error = fn (string $code, string $message, int $status) => response()->json(['error' => ['code' => $code, 'message' => $message]], $status);
        $isApi = fn (Request $r) => $r->is('api/*') || $r->expectsJson();

        $exceptions->render(fn (ApiError $e) => $error($e->errorCode, $e->getMessage(), $e->status));
        $exceptions->render(function (ValidationException $e, Request $r) use ($error, $isApi) {
            return $isApi($r) ? $error('validation_failed', collect($e->errors())->flatten()->first() ?? 'Invalid input.', 422) : null;
        });
        $exceptions->render(function (AuthenticationException $e, Request $r) use ($error, $isApi) {
            return $isApi($r) ? $error('unauthenticated', 'Please sign in again.', 401) : null;
        });
        $exceptions->render(function (ThrottleRequestsException $e, Request $r) use ($error, $isApi) {
            return $isApi($r) ? $error('too_many_requests', 'Too many requests. Please slow down.', 429) : null;
        });
        $exceptions->render(function (NotFoundHttpException|ModelNotFoundException $e, Request $r) use ($error, $isApi) {
            return $isApi($r) ? $error('not_found', 'Not found.', 404) : null;
        });
    })->create();
