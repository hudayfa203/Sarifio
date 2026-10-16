<?php

use App\Domain\Providers\Adapters;

return [

    /*
    | Environment guard. "sandbox" = staging/Test Mode: simulated providers, test
    | ledger (livemode=false), OTP may be revealed. "production" = real money,
    | only providers that passed the go-live checklist.
    */
    'mode' => env('SARIFIO_MODE', 'sandbox'),

    // Staging only. Production refuses to boot when this is true.
    'otp_reveal' => (bool) env('SANDBOX_OTP_REVEAL', false),

    'otp' => [
        'length' => 6,
        'ttl_seconds' => 300,
        'resend_after_seconds' => 60,
        'max_attempts' => 5,
        'max_per_phone_per_hour' => 5,
        'max_per_ip_per_hour' => 20,
        // Comma-separated channels that have a configured delivery provider: sms,whatsapp,email
        'channels' => env('OTP_CHANNELS', 'sms'),
        // "log" (staging only) or "provider" (bind App\Domain\Auth\OtpSender).
        'driver' => env('OTP_DRIVER', 'log'),
    ],

    'quote_ttl_seconds' => 60,

    // Default service fee: 1% (basis points). Changed only through the audited
    // admin fee endpoint, which writes fee_settings + audit_logs.
    'default_fee_bps' => 100,

    'currencies' => [
        'USD' => ['name' => 'US Dollar', 'minor_units' => 2],
        'ETB' => ['name' => 'Ethiopian Birr', 'minor_units' => 2],
        'KES' => ['name' => 'Kenyan Shilling', 'minor_units' => 2],
    ],

    /*
    | Provider registry. Adding a new wallet (any African mobile-money service)
    | = one adapter class + one entry here + a database row created by an admin.
    | Clients never need a rebuild: they render providers from GET /config.
    */
    'providers' => [
        'sahal'          => ['adapter' => Adapters\WaafiPayAdapter::class, 'method' => 'sahal'],
        'evc_plus'       => ['adapter' => Adapters\WaafiPayAdapter::class, 'method' => 'evc_plus'],
        'edahab'         => ['adapter' => Adapters\EDahabAdapter::class],
        'premier_wallet' => ['adapter' => Adapters\PremierWalletAdapter::class],
        'ebirr'          => ['adapter' => Adapters\EBirrAdapter::class],
        'mpesa'          => ['adapter' => Adapters\MpesaAdapter::class],
        'binance'        => ['adapter' => Adapters\BinanceAdapter::class],
        'visa'           => ['adapter' => Adapters\CardProcessorAdapter::class],
    ],

    'company_defaults' => [
        'name' => 'SARIFIO',
        'tagline' => 'One App. Every Exchange.',
        'website' => 'sarifio.com',
        'email' => 'info@sarifio.com',
        'support_email' => 'support@sarifio.com',
        'phone' => '+252906793240',
        'whatsapp' => '+252906793240',
    ],
];
