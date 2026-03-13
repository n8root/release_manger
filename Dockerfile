# Release Manager — минимальный образ на Alpine (Laravel + PHP-FPM).
# Рассчитан на self-hosted, до нескольких тысяч пользователей.
# На Linux контейнер можно запускать с UID/GID хоста, чтобы файлы (composer, artisan, логи)
# создавались с правами текущего пользователя.

FROM php:8.5-fpm-alpine AS base

# UID/GID хоста для прав на Linux (передаются при сборке или из .env)
ARG UID=1000
ARG GID=1000

# Расширения PHP (Alpine, минимальный набор)
RUN apk add --no-cache --virtual .build-deps \
    git unzip autoconf gcc g++ make libzip-dev libpng-dev icu-dev oniguruma-dev \
    postgresql-dev linux-headers \
    && apk add --no-cache libzip libpng icu libpq \
    && docker-php-ext-configure pdo_pgsql \
    && docker-php-ext-install -j$(nproc) \
        pdo_pgsql bcmath zip intl mbstring pcntl \
    && pecl install redis && docker-php-ext-enable redis \
    && apk del .build-deps

# Composer (официальный образ)
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
ENV COMPOSER_ALLOW_SUPERUSER=1

WORKDIR /var/www/html

# Копирование кода (Laravel в laravel/)
COPY . .

WORKDIR /var/www/html/laravel

# Зависимости PHP (Laravel в laravel/)
RUN if [ -f composer.json ]; then \
    composer install --no-dev --no-interaction --optimize-autoloader --prefer-dist; \
    fi

# Сборка фронтенда (Vite); Node ставится только на время сборки, затем удаляется
RUN if [ -f package.json ]; then \
    apk add --no-cache nodejs npm && \
    ( [ -f package-lock.json ] && npm ci || npm install ) && npm run build && rm -rf node_modules && \
    apk del nodejs npm; \
    fi

# Пользователь app с UID/GID хоста — файлы из контейнера будут с правильными правами на Linux
RUN addgroup -g ${GID} app && adduser -D -u ${UID} -G app app

# Права для Laravel (storage, cache) в laravel/
RUN set -eux; \
    for dir in storage bootstrap/cache; do \
        if [ -d "$dir" ]; then chown -R app:app "$dir"; chmod -R 775 "$dir"; fi; \
    done

EXPOSE 9000

CMD ["php-fpm"]
