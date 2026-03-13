# Release Manager

Система управления релизами (Laravel + Vue.js), self-hosted в Docker.

## Структура

- **laravel/** — приложение Laravel
- **.env** (в корне) — конфигурация контейнеров: порт, UID/GID, креды PostgreSQL для создания БД
- **laravel/.env** — конфигурация приложения (Laravel). В Docker переменные `DB_*` подставляются из корневого `.env`

## Запуск

```bash
# 1. Конфигурация контейнеров (корень проекта)
cp .env.example .env

# 2. Конфигурация приложения (Laravel)
cp laravel/.env.example laravel/.env

# 3. Ключ приложения (в контейнере)
make key
# или: docker compose run --rm app php artisan key:generate

# 4. Запуск
make up-build
# или: docker compose up -d --build
```

Приложение: http://localhost:8080 (порт задаётся в корневом `.env` как `APP_PORT`).

На Linux при необходимости задайте в корневом `.env` свои `UID` и `GID` (`id -u`, `id -g`), чтобы файлы, созданные в контейнере, имели корректные права.
