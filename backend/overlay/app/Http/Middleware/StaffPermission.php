<?php

namespace App\Http\Middleware;

use App\Models\Staff;
use App\Support\ApiError;
use Closure;
use Illuminate\Http\Request;

/** Usage: ->middleware('staff:providers.configure') */
class StaffPermission
{
    public function handle(Request $request, Closure $next, string $permission)
    {
        $staff = $request->user();
        if (! $staff instanceof Staff || ! $staff->active || ! $staff->tokenCan('admin') || ! $staff->hasPermission($permission)) {
            throw ApiError::make('forbidden', 'You do not have permission for this action.', 403);
        }

        return $next($request);
    }
}
