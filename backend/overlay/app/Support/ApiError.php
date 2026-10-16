<?php

namespace App\Support;

use RuntimeException;

/** Rendered as {"error":{"code","message"}} with the given HTTP status. */
class ApiError extends RuntimeException
{
    public function __construct(
        public readonly string $errorCode,
        string $message,
        public readonly int $status = 422,
    ) {
        parent::__construct($message);
    }

    public static function make(string $code, string $message, int $status = 422): self
    {
        return new self($code, $message, $status);
    }
}
