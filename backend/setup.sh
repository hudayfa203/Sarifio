#!/usr/bin/env bash
# Builds the SARIFIO staging API: a fresh Laravel 12 app + the SARIFIO overlay.
# Usage: ./setup.sh [target-dir]      (needs PHP 8.3, Composer, internet)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="${1:-$HERE/app}"

if [ ! -f "$APP/artisan" ]; then
  composer create-project laravel/laravel "$APP" "^12.0" --no-interaction --prefer-dist
fi
cd "$APP"
php artisan install:api --no-interaction || true   # Sanctum + personal_access_tokens migration
cp -R "$HERE/overlay/." "$APP/"
[ -f .env ] || cp "$HERE/deploy/.env.staging.example" .env
grep -q '^APP_KEY=base64' .env || php artisan key:generate --force
composer dump-autoload -o
echo
echo "Next:"
echo "  1. Edit $APP/.env (database, SEED_ADMIN_EMAIL / SEED_ADMIN_PASSWORD)."
echo "  2. php artisan migrate --seed --force"
echo "  3. php artisan test            # fee engine, ledger, idempotency, eBirr/M-Pesa flows"
echo "  4. php artisan serve & php artisan queue:work   (or use deploy/docker-compose.yml)"
