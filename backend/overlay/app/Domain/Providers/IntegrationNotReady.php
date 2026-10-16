<?php

namespace App\Domain\Providers;

use RuntimeException;

/** Thrown by an official adapter whose money-moving calls are not yet built against the provider's official specification. */
class IntegrationNotReady extends RuntimeException {}
