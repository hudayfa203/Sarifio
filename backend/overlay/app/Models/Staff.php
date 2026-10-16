<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

/** Admin-dashboard user. Separate table from customers; role-based permissions. */
class Staff extends Authenticatable
{
    use HasApiTokens;

    protected $table = 'staff';

    protected $fillable = ['name', 'email', 'password', 'role', 'active'];

    protected $hidden = ['password', 'mfa_secret'];

    /** Granular permissions per default role (Milestone 4 makes these editable). */
    public const PERMISSIONS = [
        'super_admin' => ['*'],
        'operations_manager' => ['transactions.view', 'transactions.manage', 'routes.manage', 'providers.view', 'reports.view'],
        'finance_manager' => ['transactions.view', 'ledger.view', 'fees.manage', 'rates.manage', 'reports.view', 'expenses.approve'],
        'accountant' => ['transactions.view', 'ledger.view', 'reports.view', 'expenses.create'],
        'support_agent' => ['transactions.view', 'tickets.manage'],
        'compliance_officer' => ['transactions.view', 'kyc.manage', 'transactions.review', 'reports.view'],
        'content_manager' => ['cms.manage'],
        'technical_admin' => ['providers.view', 'providers.configure', 'routes.manage', 'system.view'],
    ];

    protected function casts(): array
    {
        return [
            'password' => 'hashed',
            'mfa_secret' => 'encrypted',
            'active' => 'boolean',
        ];
    }

    public function hasPermission(string $permission): bool
    {
        $perms = self::PERMISSIONS[$this->role] ?? [];

        return in_array('*', $perms, true) || in_array($permission, $perms, true);
    }
}
