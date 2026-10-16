<?php

namespace App\Domain\Providers;

final class ProviderResult
{
    public const PENDING = 'pending';
    public const SUCCEEDED = 'succeeded';
    public const FAILED = 'failed';

    public function __construct(
        public readonly string $status,
        public readonly ?string $reference = null,
        public readonly string $message = '',
        public readonly array $raw = [],
    ) {}

    public static function pending(?string $ref = null, string $msg = ''): self
    {
        return new self(self::PENDING, $ref, $msg);
    }

    public static function ok(?string $ref = null, string $msg = 'OK'): self
    {
        return new self(self::SUCCEEDED, $ref, $msg);
    }

    public static function failed(string $msg, ?string $ref = null): self
    {
        return new self(self::FAILED, $ref, $msg);
    }

    public function succeeded(): bool
    {
        return $this->status === self::SUCCEEDED;
    }
}
