<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // ---------- staff (admin dashboard users, separate from customers) ----------
        Schema::create('staff', function (Blueprint $t) {
            $t->id();
            $t->string('name');
            $t->string('email')->unique();
            $t->string('password');
            $t->string('role', 40); // super_admin | operations_manager | finance_manager | accountant | support_agent | compliance_officer | content_manager | technical_admin
            $t->text('mfa_secret')->nullable(); // encrypted TOTP secret
            $t->boolean('active')->default(true);
            $t->timestamps();
        });

        // ---------- providers & integration manager ----------
        Schema::create('providers', function (Blueprint $t) {
            $t->id();
            $t->string('code', 40)->unique();          // sahal, ebirr, mpesa, …
            $t->string('name');
            $t->string('group_name')->nullable();      // WaafiPay
            $t->char('country', 2);                    // SO, ET, KE
            $t->char('currency', 3);                   // USD, ETB, KES
            $t->string('adapter_key', 40);             // key into config('sarifio.providers')
            $t->string('status', 30)->default('not_configured');
            $t->boolean('can_collect')->default(false);
            $t->boolean('can_payout')->default(false);
            $t->boolean('enabled')->default(false);
            $t->unsignedInteger('sort')->default(100);
            $t->json('display')->nullable();           // {description:{en,so}, website_status}
            $t->json('limits')->nullable();            // {min_minor, max_minor, daily_minor}
            $t->json('approvals')->nullable();         // {api_access, agreement, regulatory, approved_by, approved_at}
            $t->timestamp('last_test_at')->nullable();
            $t->boolean('last_test_ok')->nullable();
            $t->string('last_test_message')->nullable();
            $t->timestamps();
        });

        Schema::create('provider_credentials', function (Blueprint $t) {
            $t->id();
            $t->foreignId('provider_id')->constrained()->cascadeOnDelete();
            $t->string('environment', 20);            // sandbox | production
            $t->text('values');                        // encrypted JSON — never returned by any API
            $t->text('webhook_secret')->nullable();    // encrypted
            $t->foreignId('configured_by')->nullable()->constrained('staff');
            $t->timestamps();
            $t->unique(['provider_id', 'environment']);
        });

        Schema::create('provider_logs', function (Blueprint $t) {
            $t->id();
            $t->foreignId('provider_id')->constrained()->cascadeOnDelete();
            $t->string('level', 10);
            $t->string('event', 60);
            $t->text('message');
            $t->json('context')->nullable();
            $t->timestamp('created_at')->useCurrent();
            $t->index(['provider_id', 'created_at']);
        });

        Schema::create('exchange_routes', function (Blueprint $t) {
            $t->id();
            $t->foreignId('from_provider_id')->constrained('providers');
            $t->foreignId('to_provider_id')->constrained('providers');
            $t->boolean('enabled')->default(false);
            $t->unsignedInteger('provider_fee_bps')->default(0);
            $t->bigInteger('min_minor')->nullable();
            $t->bigInteger('max_minor')->nullable();
            $t->timestamps();
            $t->unique(['from_provider_id', 'to_provider_id']);
        });

        Schema::create('fx_rates', function (Blueprint $t) {
            $t->id();
            $t->char('from_currency', 3);
            $t->char('to_currency', 3);
            $t->bigInteger('mid_rate_micro');
            $t->unsignedInteger('spread_bps')->default(0);
            $t->string('source', 60)->default('manual');
            $t->foreignId('updated_by')->nullable()->constrained('staff');
            $t->timestamps();
            $t->unique(['from_currency', 'to_currency']);
        });

        Schema::create('fx_rate_history', function (Blueprint $t) {
            $t->id();
            $t->char('from_currency', 3);
            $t->char('to_currency', 3);
            $t->bigInteger('mid_rate_micro');
            $t->unsignedInteger('spread_bps');
            $t->foreignId('changed_by')->nullable()->constrained('staff');
            $t->timestamp('created_at')->useCurrent();
        });

        Schema::create('fee_settings', function (Blueprint $t) {
            $t->id();
            $t->unsignedInteger('fee_bps');
            $t->foreignId('changed_by')->nullable()->constrained('staff');
            $t->string('reason')->nullable();
            $t->timestamps();
        });

        // ---------- auth ----------
        Schema::create('otp_challenges', function (Blueprint $t) {
            $t->id();
            $t->string('public_id', 32)->unique();
            $t->string('phone', 20)->index();
            $t->string('name')->nullable();
            $t->string('purpose', 20);
            $t->string('channel', 20);
            $t->string('code_hash');
            $t->unsignedTinyInteger('attempts')->default(0);
            $t->timestamp('expires_at');
            $t->timestamp('consumed_at')->nullable();
            $t->string('ip', 45)->nullable();
            $t->timestamps();
        });

        // ---------- exchange ----------
        Schema::create('quotes', function (Blueprint $t) {
            $t->id();
            $t->string('public_id', 32)->unique();
            $t->foreignId('user_id')->constrained();
            $t->foreignId('from_provider_id')->constrained('providers');
            $t->foreignId('to_provider_id')->constrained('providers');
            $t->char('currency', 3);
            $t->char('receive_currency', 3);
            $t->bigInteger('amount_minor');
            $t->unsignedInteger('fee_bps');
            $t->bigInteger('fee_minor');
            $t->bigInteger('provider_fee_minor');
            $t->bigInteger('mid_rate_micro');
            $t->bigInteger('rate_micro');
            $t->bigInteger('rate_difference_minor');
            $t->bigInteger('receive_minor');
            $t->timestamp('expires_at');
            $t->timestamp('used_at')->nullable();
            $t->boolean('livemode')->default(false);
            $t->timestamps();
        });

        Schema::create('transactions', function (Blueprint $t) {
            $t->id();
            $t->string('public_id', 32)->unique();
            $t->string('reference', 32)->unique();
            $t->foreignId('user_id')->constrained();
            $t->foreignId('quote_id')->unique()->constrained();
            $t->foreignId('from_provider_id')->constrained('providers');
            $t->foreignId('to_provider_id')->constrained('providers');
            $t->char('currency', 3);
            $t->char('receive_currency', 3);
            $t->bigInteger('amount_minor');
            $t->unsignedInteger('fee_bps');
            $t->bigInteger('fee_minor');
            $t->bigInteger('provider_fee_minor');
            $t->bigInteger('rate_micro');
            $t->bigInteger('rate_difference_minor');
            $t->bigInteger('receive_minor');
            $t->text('recipient_account');            // encrypted
            $t->string('recipient_account_masked', 32);
            $t->string('recipient_name')->nullable();
            $t->string('status', 30)->index();
            $t->string('failure_reason')->nullable();
            $t->string('collection_ref')->nullable()->index();
            $t->string('payout_ref')->nullable()->index();
            $t->unsignedTinyInteger('payout_attempts')->default(0);
            $t->boolean('livemode')->default(false)->index();
            $t->string('sandbox_outcome', 20)->nullable();
            $t->timestamp('settled_at')->nullable();
            $t->timestamps();
        });

        Schema::create('transaction_events', function (Blueprint $t) {
            $t->id();
            $t->foreignId('transaction_id')->constrained()->cascadeOnDelete();
            $t->string('status', 30);
            $t->string('note')->nullable();
            $t->timestamp('created_at')->useCurrent();
        });

        Schema::create('idempotency_keys', function (Blueprint $t) {
            $t->id();
            $t->foreignId('user_id')->constrained();
            $t->string('key', 64);
            $t->string('request_hash', 64);
            $t->unsignedSmallInteger('response_status')->nullable();
            $t->json('response_body')->nullable();
            $t->foreignId('transaction_id')->nullable()->constrained();
            $t->timestamp('created_at')->useCurrent();
            $t->unique(['user_id', 'key']);
        });

        // ---------- double-entry ledger (test and live books never mix) ----------
        Schema::create('ledger_accounts', function (Blueprint $t) {
            $t->id();
            $t->string('code', 40);
            $t->string('name');
            $t->string('type', 12); // asset | liability | equity | revenue | expense
            $t->char('currency', 3);
            $t->boolean('livemode');
            $t->foreignId('provider_id')->nullable()->constrained();
            $t->timestamps();
            $t->unique(['code', 'currency', 'livemode']);
        });

        Schema::create('journal_entries', function (Blueprint $t) {
            $t->id();
            $t->string('public_id', 32)->unique();
            $t->foreignId('transaction_id')->nullable()->constrained();
            $t->string('kind', 40);       // collection_verified | payout_settled | refund | fee_reversal | expense | adjustment
            $t->string('description');
            $t->char('currency', 3);
            $t->boolean('livemode')->index();
            $t->timestamp('posted_at');
            $t->foreignId('created_by')->nullable()->constrained('staff');
            $t->timestamps();
            $t->unique(['transaction_id', 'kind', 'currency']); // never post the same step twice
        });

        Schema::create('journal_lines', function (Blueprint $t) {
            $t->id();
            $t->foreignId('journal_entry_id')->constrained()->cascadeOnDelete();
            $t->foreignId('ledger_account_id')->constrained();
            $t->bigInteger('debit_minor')->default(0);
            $t->bigInteger('credit_minor')->default(0);
        });

        // ---------- support, settings, audit ----------
        Schema::create('support_tickets', function (Blueprint $t) {
            $t->id();
            $t->string('public_id', 32)->unique();
            $t->string('number', 20)->unique();
            $t->foreignId('user_id')->constrained();
            $t->foreignId('transaction_id')->nullable()->constrained();
            $t->string('subject');
            $t->text('message');
            $t->string('status', 20)->default('open');
            $t->string('priority', 10)->default('normal');
            $t->foreignId('assigned_to')->nullable()->constrained('staff');
            $t->timestamps();
        });

        Schema::create('settings', function (Blueprint $t) {
            $t->string('key', 80)->primary();
            $t->json('value');
            $t->foreignId('updated_by')->nullable()->constrained('staff');
            $t->timestamps();
        });

        Schema::create('audit_logs', function (Blueprint $t) {
            $t->id();
            $t->foreignId('actor_id')->nullable()->constrained('staff');
            $t->string('action', 80);
            $t->string('subject_type', 80)->nullable();
            $t->string('subject_id', 40)->nullable();
            $t->json('before')->nullable();
            $t->json('after')->nullable();
            $t->string('ip', 45)->nullable();
            $t->timestamp('created_at')->useCurrent();
            $t->index(['subject_type', 'subject_id']);
        });
    }

    public function down(): void
    {
        foreach ([
            'audit_logs', 'settings', 'support_tickets', 'journal_lines', 'journal_entries', 'ledger_accounts',
            'idempotency_keys', 'transaction_events', 'transactions', 'quotes', 'otp_challenges', 'fee_settings',
            'fx_rate_history', 'fx_rates', 'exchange_routes', 'provider_logs', 'provider_credentials', 'providers', 'staff',
        ] as $table) {
            Schema::dropIfExists($table);
        }
    }
};
