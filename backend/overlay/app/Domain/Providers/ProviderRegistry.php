<?php

namespace App\Domain\Providers;

use App\Domain\Providers\Adapters\SandboxAdapter;
use App\Models\Provider;
use InvalidArgumentException;

/**
 * Resolves the adapter for a provider. In sandbox mode every provider is
 * served by the simulated SandboxAdapter, so no real money can move; in
 * production the official adapter is used and only for live providers.
 */
class ProviderRegistry
{
    public function official(Provider $provider): ProviderAdapter
    {
        $def = config('sarifio.providers.'.$provider->adapter_key);
        if (! $def || ! class_exists($def['adapter'])) {
            throw new InvalidArgumentException("No adapter registered for provider [{$provider->adapter_key}].");
        }

        return new $def['adapter']($provider, $def);
    }

    public function forMoneyMovement(Provider $provider): ProviderAdapter
    {
        if (config('sarifio.mode') !== 'production') {
            return new SandboxAdapter($provider);
        }
        if ($provider->status !== 'live' || ! $provider->enabled) {
            throw new IntegrationNotReady("{$provider->name} is not live.");
        }

        return $this->official($provider);
    }

    public function environment(): string
    {
        return config('sarifio.mode') === 'production' ? 'production' : 'sandbox';
    }

    /** @return array<string,mixed> */
    public function credentials(Provider $provider, ?string $environment = null): array
    {
        $env = $environment ?? $this->environment();

        return $provider->credentials()->where('environment', $env)->first()?->values ?? [];
    }
}
