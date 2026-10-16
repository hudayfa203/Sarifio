FROM php:8.3-cli-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends git unzip libpq-dev libzip-dev \
 && docker-php-ext-install pdo_pgsql bcmath zip pcntl \
 && pecl install redis && docker-php-ext-enable redis \
 && rm -rf /var/lib/apt/lists/*
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
WORKDIR /srv
COPY . /srv/backend
RUN /srv/backend/setup.sh /srv/app && cd /srv/app && composer install --no-dev -o
WORKDIR /srv/app
EXPOSE 8000
CMD ["sh", "-c", "php artisan migrate --force && php artisan config:cache && php artisan route:cache && php artisan serve --host=0.0.0.0 --port=8000"]
