<?php

namespace App\Domain\Auth;

/** Implement per SMS gateway / WhatsApp Business provider / mailer and bind in AppServiceProvider. */
interface OtpSender
{
    public function send(string $channel, string $phone, ?string $email, string $code): void;
}
