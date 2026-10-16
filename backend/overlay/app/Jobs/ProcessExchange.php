<?php

namespace App\Jobs;

use App\Domain\Exchange\ExchangeService;
use App\Domain\Providers\IntegrationNotReady;
use App\Models\Transaction;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

/**
 * Drives an exchange through its legs. In sandbox mode short delays make the
 * Samsung test app show each step; in production collection/payout results
 * usually arrive through verified webhooks instead.
 */
class ProcessExchange implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;

    public function __construct(public int $transactionId, public string $step) {}

    public function handle(ExchangeService $exchanges): void
    {
        $sandbox = config('sarifio.mode') !== 'production';
        try {
            if ($this->step === 'collect') {
                $next = $exchanges->collect($this->transactionId);
                if ($next === 'payout') {
                    self::dispatch($this->transactionId, 'payout')->delay(now()->addSeconds($sandbox ? 3 : 0));
                }
            } elseif ($this->step === 'payout') {
                $exchanges->payout($this->transactionId);
            }
        } catch (IntegrationNotReady $e) {
            $tx = Transaction::query()->find($this->transactionId);
            if ($tx && ! in_array($tx->status, ['failed', 'refunded', 'settled', 'manual_review'], true)) {
                $tx->update(['failure_reason' => 'This provider is not available yet.']);
                $tx->events()->create(['status' => $tx->status, 'note' => $e->getMessage()]);
            }
            $this->fail($e);
        }
    }
}
