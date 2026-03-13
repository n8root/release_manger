# Release Manager — запуск проекта, шелл в контейнерах, artisan/composer/npm
# Использование: make [цель]; make help — список целей

COMPOSE = docker compose
APP = app
SHELL_CMD ?= sh

.PHONY: help up down build up-build restart shell sh artisan composer npm migrate fresh key config-clear logs logs-app ps install

help:
	@echo "Release Manager — основные цели:"
	@echo "  make up          — поднять контейнеры (detached)"
	@echo "  make down        — остановить и снять контейнеры"
	@echo "  make build       — собрать образы"
	@echo "  make up-build    — поднять с пересборкой образов"
	@echo "  make restart     — перезапустить контейнеры"
	@echo ""
	@echo "  make shell       — шелл в контейнер app (sh; SHELL_CMD=bash если установлен)"
	@echo "  make sh          — то же, make shell"
	@echo ""
	@echo "  make artisan cmd='...'  — php artisan в app (например: make artisan cmd=migrate)"
	@echo "  make composer args='...' — composer в app (например: make composer args=install)"
	@echo "  make npm args='...'      — npm в app (например: make npm args=run build)"
	@echo ""
	@echo "  make migrate     — php artisan migrate"
	@echo "  make fresh       — php artisan migrate:fresh"
	@echo "  make key         — php artisan key:generate"
	@echo "  make config-clear — php artisan config:clear"
	@echo ""
	@echo "  make logs        — логи всех сервисов (follow)"
	@echo "  make logs-app    — логи только app"
	@echo "  make ps          — статус контейнеров"
	@echo ""
	@echo "  make install     — первичная установка (env, ключ, миграции)"

# --- Запуск и сборка ---

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

build:
	$(COMPOSE) build

up-build:
	$(COMPOSE) up -d --build

restart:
	$(COMPOSE) restart

# --- Шелл в контейнер app ---

shell:
	$(COMPOSE) exec $(APP) $(SHELL_CMD)

sh:
	$(COMPOSE) exec $(APP) sh

# --- Artisan, Composer, NPM (в app/) ---

artisan:
	$(COMPOSE) exec $(APP) php artisan $(cmd)

composer:
	$(COMPOSE) exec $(APP) composer $(args)

npm:
	$(COMPOSE) exec $(APP) npm $(args)

# --- Частые команды Laravel ---

migrate:
	$(COMPOSE) exec $(APP) php artisan migrate

fresh:
	$(COMPOSE) exec $(APP) php artisan migrate:fresh

key:
	$(COMPOSE) exec $(APP) php artisan key:generate

config-clear:
	$(COMPOSE) exec $(APP) php artisan config:clear

# --- Логи и статус ---

logs:
	$(COMPOSE) logs -f

logs-app:
	$(COMPOSE) logs -f $(APP)

ps:
	$(COMPOSE) ps

# --- Первичная установка (нужен .env: cp .env.example .env) ---

install: build
	@test -f .env || (echo "Создайте .env: cp .env.example .env" && exit 1)
	$(COMPOSE) run --rm $(APP) php artisan key:generate
	$(COMPOSE) up -d
	@echo "Ожидание БД..."
	@sleep 3
	$(COMPOSE) exec $(APP) php artisan migrate --force
	@echo "Готово. Приложение: http://localhost:$${APP_PORT:-8080}"
