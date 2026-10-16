<?php

namespace App\Domain\Ledger;

use App\Models\JournalEntry;
use App\Models\LedgerAccount;
use App\Models\Provider;
use App\Models\Transaction;
use App\Support\Ids;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use LogicException;

/**
 * Double-entry ledger. Every journal is single-currency and must balance
 * (Σ debit = Σ credit). Test (livemode=false) and live books use separate
 * accounts, so simulated exchanges can never appear as business revenue.
 * Customer principal is a liability — only the 1% fee and the FX spread are
 * recognised as revenue, and only when an exchange settles.
 */
class Ledger
{
    public function account(string $code, string $name, string $type, string $currency, bool $livemode, ?int $providerId = null): LedgerAccount
    {
        return LedgerAccount::query()->firstOrCreate(
            ['code' => $code, 'currency' => $currency, 'livemode' => $livemode],
            ['name' => $name, 'type' => $type, 'provider_id' => $providerId],
        );
    }

    public function clearing(Provider $p, string $currency, bool $live): LedgerAccount
    {
        return $this->account("1100-{$p->code}", "{$p->name} clearing", 'asset', $currency, $live, $p->id);
    }

    public function fxPosition(string $currency, bool $live): LedgerAccount
    {
        return $this->account('1900', 'FX conversion position', 'asset', $currency, $live);
    }

    public function customerFundsPending(string $currency, bool $live): LedgerAccount
    {
        return $this->account('2100', 'Customer funds pending payout', 'liability', $currency, $live);
    }

    public function providerChargesPayable(string $currency, bool $live): LedgerAccount
    {
        return $this->account('2200', 'Provider charges payable', 'liability', $currency, $live);
    }

    public function feeRevenue(string $currency, bool $live): LedgerAccount
    {
        return $this->account('4000', 'Exchange service fee revenue (1%)', 'revenue', $currency, $live);
    }

    public function fxSpreadIncome(string $currency, bool $live): LedgerAccount
    {
        return $this->account('4100', 'FX spread income', 'revenue', $currency, $live);
    }

    /**
     * @param  list<array{0:LedgerAccount,1:int,2:int}>  $lines  [account, debit_minor, credit_minor]
     */
    public function post(string $kind, ?Transaction $tx, string $currency, bool $livemode, string $description, array $lines, ?int $staffId = null): JournalEntry
    {
        $lines = array_values(array_filter($lines, fn ($l) => $l[1] !== 0 || $l[2] !== 0));
        $debit = array_sum(array_column($lines, 1));
        $credit = array_sum(array_column($lines, 2));
        if ($debit !== $credit || $debit <= 0) {
            throw new LogicException("Unbalanced journal [{$kind}]: debit {$debit} ≠ credit {$credit}.");
        }
        foreach ($lines as [$account, $d, $c]) {
            if ($account->currency !== $currency || $account->livemode !== $livemode) {
                throw new LogicException("Account {$account->code} does not belong to this {$currency} journal.");
            }
            if ($d < 0 || $c < 0) {
                throw new LogicException('Journal lines cannot be negative.');
            }
        }

        try {
            return DB::transaction(function () use ($kind, $tx, $currency, $livemode, $description, $lines, $staffId) {
                $entry = JournalEntry::query()->create([
                    'public_id' => Ids::make('je_'),
                    'transaction_id' => $tx?->id,
                    'kind' => $kind,
                    'description' => $description,
                    'currency' => $currency,
                    'livemode' => $livemode,
                    'posted_at' => now(),
                    'created_by' => $staffId,
                ]);
                foreach ($lines as [$account, $d, $c]) {
                    $entry->lines()->create(['ledger_account_id' => $account->id, 'debit_minor' => $d, 'credit_minor' => $c]);
                }

                return $entry;
            });
        } catch (UniqueConstraintViolationException) {
            // Same step already posted for this transaction — posting is idempotent.
            return JournalEntry::query()->where(['transaction_id' => $tx?->id, 'kind' => $kind, 'currency' => $currency])->firstOrFail();
        }
    }

    /** Trial balance per account for a currency and book. */
    public function trialBalance(string $currency, bool $livemode): array
    {
        return DB::table('journal_lines')
            ->join('journal_entries', 'journal_entries.id', '=', 'journal_lines.journal_entry_id')
            ->join('ledger_accounts', 'ledger_accounts.id', '=', 'journal_lines.ledger_account_id')
            ->where('journal_entries.currency', $currency)
            ->where('journal_entries.livemode', $livemode)
            ->groupBy('ledger_accounts.id', 'ledger_accounts.code', 'ledger_accounts.name', 'ledger_accounts.type')
            ->select('ledger_accounts.code', 'ledger_accounts.name', 'ledger_accounts.type')
            ->selectRaw('SUM(journal_lines.debit_minor) AS debit_minor, SUM(journal_lines.credit_minor) AS credit_minor')
            ->orderBy('ledger_accounts.code')
            ->get()
            ->map(fn ($r) => (array) $r)
            ->all();
    }
}
