# Проектирование базы данных — Release Manager

**СУБД**: PostgreSQL 16  
**Кодировка**: UTF-8  
**Timezone**: UTC (конвертация в локальное время на уровне приложения)

---

## Принципы проектирования

1. **Нормализация**: 3НФ, где это оправдано
2. **snake_case** для имён таблиц и полей
3. **Индексы**: для всех внешних ключей, полей фильтрации и сортировки
4. **Soft deletes**: для критичных таблиц (releases, incidents, services)
5. **Timestamps**: `created_at`, `updated_at` везде где важно видить лог создания и редактирования записей
6. **Аудит**: отдельные таблицы для истории изменений
7. **JSON поля**: для гибких настроек и метаданных
8. **Enum-типы**: через строки или отдельные таблицы справочников

---

## 1. Аутентификация и пользователи

### Таблица: `users`
Пользователи системы.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `name` | VARCHAR(255) | Имя пользователя | NOT NULL |
| `email` | VARCHAR(255) | Email (логин) | UNIQUE, NOT NULL |
| `email_verified_at` | TIMESTAMP | Дата верификации email | NULL |
| `password` | VARCHAR(255) | Хеш пароля | NOT NULL |
| `avatar` | VARCHAR(500) | URL аватара | NULL |
| `locale` | VARCHAR(5) | Язык интерфейса (ru, en) | DEFAULT 'ru' |
| `timezone` | VARCHAR(50) | Часовой пояс | DEFAULT 'UTC' |
| `is_active` | BOOLEAN | Активен ли пользователь | DEFAULT TRUE |
| `last_login_at` | TIMESTAMP | Последний вход | NULL |
| `remember_token` | VARCHAR(100) | Токен "Запомнить меня" | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (email)`
- `INDEX (is_active)`

---

## 2. RBAC (Spatie Laravel Permission)

### Таблица: `roles`
Роли в системе.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `name` | VARCHAR(255) | Название роли | UNIQUE, NOT NULL |
| `guard_name` | VARCHAR(255) | Guard (web, api) | NOT NULL, DEFAULT 'web' |
| `description` | TEXT | Описание роли | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Роли**:
- `admin` — Администратор
- `service_owner` — Владелец сервиса
- `developer` — Разработчик
- `tester` — Тестировщик
- `incident_manager` — Инцидент-менеджер

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (name, guard_name)`

---

### Таблица: `permissions`
Разрешения в системе.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `name` | VARCHAR(255) | Название разрешения | UNIQUE, NOT NULL |
| `guard_name` | VARCHAR(255) | Guard (web, api) | NOT NULL, DEFAULT 'web' |
| `description` | TEXT | Описание разрешения | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Примеры разрешений**:
- `view-releases`, `create-releases`, `edit-releases`, `delete-releases`
- `deploy-releases`, `rollback-releases`
- `manage-users`, `manage-teams`, `manage-services`
- `manage-incidents`
- `view-settings`, `manage-settings`

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (name, guard_name)`

---

### Таблица: `model_has_permissions`
Связь пользователей с разрешениями (прямое назначение).

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `permission_id` | BIGINT | FK на permissions | NOT NULL |
| `model_type` | VARCHAR(255) | Тип модели (User) | NOT NULL |
| `model_id` | BIGINT | ID модели | NOT NULL |

**Индексы**:
- `PRIMARY KEY (permission_id, model_id, model_type)`
- `INDEX (model_id, model_type)`
- `FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE`

---

### Таблица: `model_has_roles`
Связь пользователей с ролями.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `role_id` | BIGINT | FK на roles | NOT NULL |
| `model_type` | VARCHAR(255) | Тип модели (User) | NOT NULL |
| `model_id` | BIGINT | ID модели | NOT NULL |

**Индексы**:
- `PRIMARY KEY (role_id, model_id, model_type)`
- `INDEX (model_id, model_type)`
- `FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE`

---

### Таблица: `role_has_permissions`
Связь ролей с разрешениями.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `permission_id` | BIGINT | FK на permissions | NOT NULL |
| `role_id` | BIGINT | FK на roles | NOT NULL |

**Индексы**:
- `PRIMARY KEY (permission_id, role_id)`
- `FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE`
- `FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE`

---

## 3. Команды

### Таблица: `teams`
Команды разработки.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `name` | VARCHAR(255) | Название команды | UNIQUE, NOT NULL |
| `slug` | VARCHAR(255) | URL-friendly имя | UNIQUE, NOT NULL |
| `description` | TEXT | Описание команды | NULL |
| `notification_presets` | JSONB | Пресеты уведомлений | NULL |
| `settings` | JSONB | Дополнительные настройки | NULL |
| `is_active` | BOOLEAN | Активна ли команда | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**notification_presets** (пример):
```json
{
  "channels": [
    {
      "type": "slack",
      "webhook_url": "https://...",
      "name": "Team Channel"
    },
    {
      "type": "telegram",
      "chat_id": "-123456789",
      "name": "Team Chat"
    }
  ],
  "events": [
    "release.status_changed",
    "release.deployed",
    "release.rolled_back",
    "incident.opened",
    "incident.closed"
  ]
}
```

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (name)`
- `UNIQUE INDEX (slug)`
- `INDEX (is_active)`

---

### Таблица: `team_user`
Связь пользователей с командами (многие ко многим).

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `team_id` | BIGINT | FK на teams | NOT NULL |
| `user_id` | BIGINT | FK на users | NOT NULL |
| `role` | VARCHAR(50) | Роль в команде | NULL |
| `created_at` | TIMESTAMP | Дата добавления | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (team_id, user_id)`
- `FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE`
- `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`

---

## 4. Сервисы

### Таблица: `services`
Сервисы (микросервисы, приложения).

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `team_id` | BIGINT | FK на teams | NOT NULL |
| `name` | VARCHAR(255) | Название сервиса | NOT NULL |
| `slug` | VARCHAR(255) | URL-friendly имя | UNIQUE, NOT NULL |
| `description` | TEXT | Описание сервиса | NULL |
| `repository_url` | VARCHAR(500) | URL репозитория | NULL |
| `integration_type` | VARCHAR(50) | Тип интеграции (gitlab, github) | NULL |
| `integration_config` | JSONB | Конфиг интеграции | NULL |
| `versioning_strategy` | VARCHAR(50) | Стратегия версий (manual, semver, date) | DEFAULT 'manual' |
| `settings` | JSONB | Дополнительные настройки | NULL |
| `is_active` | BOOLEAN | Активен ли сервис | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |
| `deleted_at` | TIMESTAMP | Дата удаления (soft delete) | NULL |

**integration_config** (пример):
```json
{
  "provider": "gitlab",
  "project_id": "12345",
  "api_url": "https://gitlab.com/api/v4",
  "access_token": "encrypted_token",
  "default_branch": "main"
}
```

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (slug)`
- `INDEX (team_id)`
- `INDEX (is_active)`
- `INDEX (deleted_at)`
- `FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE RESTRICT`

---

### Таблица: `service_environments`
Окружения сервисов (staging, production, etc.).

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `service_id` | BIGINT | FK на services | NOT NULL |
| `name` | VARCHAR(100) | Название окружения | NOT NULL |
| `slug` | VARCHAR(100) | URL-friendly имя | NOT NULL |
| `description` | TEXT | Описание окружения | NULL |
| `deploy_config` | JSONB | Конфиг деплоя | NULL |
| `url` | VARCHAR(500) | URL окружения | NULL |
| `order` | INTEGER | Порядок сортировки | DEFAULT 0 |
| `is_active` | BOOLEAN | Активно ли окружение | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**deploy_config** (пример):
```json
{
  "pipeline_url": "https://gitlab.com/project/pipelines",
  "deploy_job_name": "deploy:production",
  "rollback_job_name": "rollback:production",
  "webhook_secret": "encrypted_secret",
  "health_check_url": "https://api.example.com/health"
}
```

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (service_id, slug)`
- `INDEX (service_id, is_active)`
- `INDEX (order)`
- `FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE`

---

## 5. Релизы

### Таблица: `releases`
Релизы приложений.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `service_id` | BIGINT | FK на services | NOT NULL |
| `environment_id` | BIGINT | FK на service_environments | NULL |
| `responsible_user_id` | BIGINT | FK на users (ответственный) | NULL |
| `name` | VARCHAR(255) | Название релиза | NOT NULL |
| `version` | VARCHAR(100) | Версия релиза | NOT NULL |
| `description` | TEXT | Описание релиза | NULL |
| `status` | VARCHAR(50) | Статус релиза | NOT NULL, DEFAULT 'draft' |
| `planned_at` | TIMESTAMP | Планируемая дата релиза | NULL |
| `deployed_at` | TIMESTAMP | Дата деплоя | NULL |
| `rolled_back_at` | TIMESTAMP | Дата отката | NULL |
| `release_branch` | VARCHAR(255) | Название релизной ветки | NULL |
| `release_tag` | VARCHAR(255) | Git tag | NULL |
| `template_id` | BIGINT | FK на release_templates | NULL |
| `metadata` | JSONB | Дополнительные метаданные | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |
| `deleted_at` | TIMESTAMP | Дата удаления (soft delete) | NULL |

**Статусы** (`status`):
- `draft` — Черновик
- `ready` — Готов к релизу
- `deploying` — Деплоится
- `deployed` — Задеплоен
- `rolling_back` — Откатывается
- `rolled_back` — Откачен
- `failed` — Ошибка деплоя

**metadata** (пример):
```json
{
  "artifact_url": "https://...",
  "build_number": "1234",
  "commit_sha": "abc123",
  "author": "john.doe",
  "custom_fields": {}
}
```

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (service_id, status)`
- `INDEX (environment_id)`
- `INDEX (responsible_user_id)`
- `INDEX (status)`
- `INDEX (planned_at)`
- `INDEX (created_at)`
- `INDEX (deleted_at)`
- `UNIQUE INDEX (service_id, version)` (если версии уникальны в рамках сервиса)
- `FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT`
- `FOREIGN KEY (environment_id) REFERENCES service_environments(id) ON DELETE SET NULL`
- `FOREIGN KEY (responsible_user_id) REFERENCES users(id) ON DELETE SET NULL`

---

### Таблица: `release_merge_requests`
Merge Requests в релизе.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `release_id` | BIGINT | FK на releases | NOT NULL |
| `external_id` | VARCHAR(255) | ID MR во внешней системе | NOT NULL |
| `external_iid` | INTEGER | Internal ID MR | NULL |
| `title` | VARCHAR(500) | Заголовок MR | NOT NULL |
| `description` | TEXT | Описание MR | NULL |
| `author` | VARCHAR(255) | Автор MR | NULL |
| `source_branch` | VARCHAR(255) | Исходная ветка | NULL |
| `target_branch` | VARCHAR(255) | Целевая ветка | NULL |
| `url` | VARCHAR(500) | URL MR | NULL |
| `state` | VARCHAR(50) | Статус MR (opened, merged, closed) | NOT NULL |
| `merged_at` | TIMESTAMP | Дата мержа | NULL |
| `metadata` | JSONB | Дополнительная информация | NULL |
| `created_at` | TIMESTAMP | Дата добавления в релиз | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (release_id)`
- `INDEX (external_id)`
- `INDEX (state)`
- `FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE CASCADE`

---

### Таблица: `release_risk_factors`
Факторы риска релиза.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `release_id` | BIGINT | FK на releases | NOT NULL |
| `risk_factor_id` | BIGINT | FK на risk_factors | NOT NULL |
| `source` | VARCHAR(50) | Источник (manual, ai, auto) | NOT NULL, DEFAULT 'manual' |
| `severity` | VARCHAR(50) | Уровень риска (low, medium, high, critical) | NOT NULL, DEFAULT 'medium' |
| `details` | TEXT | Детали/причина риска | NULL |
| `added_by_user_id` | BIGINT | FK на users | NULL |
| `created_at` | TIMESTAMP | Дата добавления | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (release_id)`
- `INDEX (risk_factor_id)`
- `INDEX (severity)`
- `FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE CASCADE`
- `FOREIGN KEY (risk_factor_id) REFERENCES risk_factors(id) ON DELETE CASCADE`
- `FOREIGN KEY (added_by_user_id) REFERENCES users(id) ON DELETE SET NULL`

---

### Таблица: `release_checklists`
Чеклисты проверок для релизов.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `release_id` | BIGINT | FK на releases | NOT NULL |
| `checklist_template_id` | BIGINT | FK на checklist_templates | NULL |
| `title` | VARCHAR(255) | Название пункта | NOT NULL |
| `description` | TEXT | Описание пункта | NULL |
| `type` | VARCHAR(50) | Тип проверки (manual, auto) | NOT NULL, DEFAULT 'manual' |
| `required_for_status` | VARCHAR(50) | Обязателен для статуса | NULL |
| `required_role` | VARCHAR(50) | Роль для апрува | NULL |
| `is_completed` | BOOLEAN | Выполнен ли пункт | DEFAULT FALSE |
| `completed_by_user_id` | BIGINT | FK на users | NULL |
| `completed_at` | TIMESTAMP | Дата выполнения | NULL |
| `auto_check_config` | JSONB | Конфиг автопроверки | NULL |
| `order` | INTEGER | Порядок сортировки | DEFAULT 0 |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (release_id, is_completed)`
- `INDEX (checklist_template_id)`
- `INDEX (order)`
- `FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE CASCADE`
- `FOREIGN KEY (completed_by_user_id) REFERENCES users(id) ON DELETE SET NULL`

---

### Таблица: `release_deployment_rules`
Правила выкатки для релизов.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `release_id` | BIGINT | FK на releases | NOT NULL |
| `rule_type` | VARCHAR(50) | Тип правила (depends_on, after_date, schedule) | NOT NULL |
| `target_release_id` | BIGINT | FK на releases (зависимость) | NULL |
| `target_date` | TIMESTAMP | Целевая дата | NULL |
| `schedule` | VARCHAR(100) | Расписание (например, "Tue,Thu") | NULL |
| `is_blocking` | BOOLEAN | Блокирующее ли правило | DEFAULT TRUE |
| `description` | TEXT | Описание правила | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (release_id)`
- `INDEX (target_release_id)`
- `INDEX (rule_type)`
- `FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE CASCADE`
- `FOREIGN KEY (target_release_id) REFERENCES releases(id) ON DELETE CASCADE`

---

### Таблица: `release_notifications`
Правила уведомлений для конкретных релизов.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `release_id` | BIGINT | FK на releases | NOT NULL |
| `channel_type` | VARCHAR(50) | Тип канала (slack, telegram, email) | NOT NULL |
| `channel_config` | JSONB | Конфиг канала | NOT NULL |
| `events` | JSONB | События для уведомлений | NOT NULL |
| `is_active` | BOOLEAN | Активно ли правило | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**events** (пример):
```json
["release.status_changed", "release.deployed", "release.rolled_back"]
```

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (release_id, is_active)`
- `FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE CASCADE`

---

### Таблица: `release_deployments`
История деплоев и откатов.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `release_id` | BIGINT | FK на releases | NOT NULL |
| `environment_id` | BIGINT | FK на service_environments | NOT NULL |
| `user_id` | BIGINT | FK на users (кто запустил) | NOT NULL |
| `type` | VARCHAR(50) | Тип действия (deploy, rollback) | NOT NULL |
| `status` | VARCHAR(50) | Статус (pending, running, success, failed) | NOT NULL, DEFAULT 'pending' |
| `pipeline_id` | VARCHAR(255) | ID пайплайна в CI/CD | NULL |
| `pipeline_url` | VARCHAR(500) | URL пайплайна | NULL |
| `logs` | TEXT | Логи деплоя | NULL |
| `error_message` | TEXT | Сообщение об ошибке | NULL |
| `started_at` | TIMESTAMP | Время начала | NULL |
| `finished_at` | TIMESTAMP | Время завершения | NULL |
| `metadata` | JSONB | Дополнительные данные | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (release_id)`
- `INDEX (environment_id)`
- `INDEX (user_id)`
- `INDEX (status)`
- `INDEX (created_at)`
- `FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE CASCADE`
- `FOREIGN KEY (environment_id) REFERENCES service_environments(id) ON DELETE RESTRICT`
- `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT`

---

### Таблица: `release_changelog`
История изменений релиза (аудит).

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `release_id` | BIGINT | FK на releases | NOT NULL |
| `user_id` | BIGINT | FK на users (кто изменил) | NULL |
| `action` | VARCHAR(50) | Тип действия (created, updated, status_changed, etc.) | NOT NULL |
| `field` | VARCHAR(100) | Поле, которое изменилось | NULL |
| `old_value` | TEXT | Старое значение | NULL |
| `new_value` | TEXT | Новое значение | NULL |
| `metadata` | JSONB | Дополнительная информация | NULL |
| `created_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (release_id, created_at DESC)`
- `INDEX (user_id)`
- `INDEX (action)`
- `FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE CASCADE`
- `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL`

---

## 6. Инциденты

### Таблица: `incidents`
Инциденты, связанные с релизами.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `release_id` | BIGINT | FK на releases | NULL |
| `service_id` | BIGINT | FK на services | NOT NULL |
| `title` | VARCHAR(500) | Заголовок инцидента | NOT NULL |
| `description` | TEXT | Описание инцидента | NULL |
| `status` | VARCHAR(50) | Статус (open, investigating, resolved, closed) | NOT NULL, DEFAULT 'open' |
| `severity` | VARCHAR(50) | Важность (low, medium, high, critical) | NOT NULL, DEFAULT 'medium' |
| `reported_by_user_id` | BIGINT | FK на users | NULL |
| `assigned_to_user_id` | BIGINT | FK на users | NULL |
| `external_ticket_url` | VARCHAR(500) | URL тикета в трекере | NULL |
| `resolved_at` | TIMESTAMP | Дата решения | NULL |
| `closed_at` | TIMESTAMP | Дата закрытия | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |
| `deleted_at` | TIMESTAMP | Дата удаления (soft delete) | NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (release_id)`
- `INDEX (service_id)`
- `INDEX (status)`
- `INDEX (severity)`
- `INDEX (created_at)`
- `INDEX (deleted_at)`
- `FOREIGN KEY (release_id) REFERENCES releases(id) ON DELETE SET NULL`
- `FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE RESTRICT`
- `FOREIGN KEY (reported_by_user_id) REFERENCES users(id) ON DELETE SET NULL`
- `FOREIGN KEY (assigned_to_user_id) REFERENCES users(id) ON DELETE SET NULL`

---

### Таблица: `incident_changelog`
История изменений инцидента (аудит).

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `incident_id` | BIGINT | FK на incidents | NOT NULL |
| `user_id` | BIGINT | FK на users | NULL |
| `action` | VARCHAR(50) | Тип действия (created, updated, status_changed, etc.) | NOT NULL |
| `field` | VARCHAR(100) | Поле, которое изменилось | NULL |
| `old_value` | TEXT | Старое значение | NULL |
| `new_value` | TEXT | Новое значение | NULL |
| `metadata` | JSONB | Дополнительная информация | NULL |
| `created_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (incident_id, created_at DESC)`
- `INDEX (user_id)`
- `FOREIGN KEY (incident_id) REFERENCES incidents(id) ON DELETE CASCADE`
- `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL`

---

## 7. Шаблоны и справочники

### Таблица: `risk_factors`
Справочник факторов риска.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `name` | VARCHAR(255) | Название фактора | UNIQUE, NOT NULL |
| `description` | TEXT | Описание фактора | NULL |
| `category` | VARCHAR(100) | Категория (code, infrastructure, business) | NULL |
| `default_severity` | VARCHAR(50) | Уровень риска по умолчанию | DEFAULT 'medium' |
| `is_active` | BOOLEAN | Активен ли фактор | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Примеры**:
- "Большое количество изменений" (>500 строк кода)
- "Изменения в критичном модуле"
- "Отсутствие тестов"
- "Первый релиз сервиса"
- "Hotfix без тестирования"

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (name)`
- `INDEX (is_active)`

---

### Таблица: `release_templates`
Шаблоны релизов.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `name` | VARCHAR(255) | Название шаблона | NOT NULL |
| `description` | TEXT | Описание шаблона | NULL |
| `service_type` | VARCHAR(100) | Тип сервиса (backend, frontend, critical) | NULL |
| `default_checklist` | JSONB | Дефолтный чеклист | NULL |
| `default_deployment_rules` | JSONB | Дефолтные правила выкатки | NULL |
| `default_notifications` | JSONB | Дефолтные уведомления | NULL |
| `is_active` | BOOLEAN | Активен ли шаблон | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (is_active)`

---

### Таблица: `checklist_templates`
Шаблоны чеклистов.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `name` | VARCHAR(255) | Название шаблона | NOT NULL |
| `description` | TEXT | Описание шаблона | NULL |
| `items` | JSONB | Пункты чеклиста | NOT NULL |
| `service_type` | VARCHAR(100) | Тип сервиса | NULL |
| `is_active` | BOOLEAN | Активен ли шаблон | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**items** (пример):
```json
[
  {
    "title": "Тесты пройдены",
    "type": "auto",
    "required_for_status": "ready",
    "order": 1
  },
  {
    "title": "План отката валидирован",
    "type": "manual",
    "required_role": "service_owner",
    "required_for_status": "ready",
    "order": 2
  }
]
```

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (is_active)`

---

## 8. Настройки и интеграции

### Таблица: `integrations`
Интеграции с внешними системами.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `name` | VARCHAR(255) | Название интеграции | NOT NULL |
| `type` | VARCHAR(50) | Тип (gitlab, github, slack, telegram, tracker) | NOT NULL |
| `config` | JSONB | Конфигурация интеграции | NOT NULL |
| `is_active` | BOOLEAN | Активна ли интеграция | DEFAULT TRUE |
| `last_sync_at` | TIMESTAMP | Последняя синхронизация | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**config** (пример для GitLab):
```json
{
  "api_url": "https://gitlab.com/api/v4",
  "access_token": "encrypted_token",
  "webhook_secret": "encrypted_secret",
  "default_branch": "main"
}
```

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (type, is_active)`

---

### Таблица: `notification_channels`
Каналы уведомлений.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `team_id` | BIGINT | FK на teams | NULL |
| `name` | VARCHAR(255) | Название канала | NOT NULL |
| `type` | VARCHAR(50) | Тип (slack, telegram, email, webhook) | NOT NULL |
| `config` | JSONB | Конфигурация канала | NOT NULL |
| `is_active` | BOOLEAN | Активен ли канал | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**config** (пример для Slack):
```json
{
  "webhook_url": "https://hooks.slack.com/services/...",
  "channel": "#releases",
  "username": "Release Bot",
  "icon_emoji": ":rocket:"
}
```

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (team_id)`
- `INDEX (type, is_active)`
- `FOREIGN KEY (team_id) REFERENCES teams(id) ON DELETE CASCADE`

---

### Таблица: `notification_logs`
Лог отправленных уведомлений.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `channel_id` | BIGINT | FK на notification_channels | NULL |
| `event_type` | VARCHAR(100) | Тип события | NOT NULL |
| `related_type` | VARCHAR(100) | Тип связанной сущности (Release, Incident) | NOT NULL |
| `related_id` | BIGINT | ID связанной сущности | NOT NULL |
| `status` | VARCHAR(50) | Статус отправки (pending, sent, failed) | NOT NULL, DEFAULT 'pending' |
| `payload` | JSONB | Отправленные данные | NULL |
| `error_message` | TEXT | Сообщение об ошибке | NULL |
| `sent_at` | TIMESTAMP | Дата отправки | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (channel_id, status)`
- `INDEX (related_type, related_id)`
- `INDEX (created_at)`
- `FOREIGN KEY (channel_id) REFERENCES notification_channels(id) ON DELETE SET NULL`

---

## 9. Календарь и расписание

### Таблица: `deployment_schedules`
Правила расписания деплоев по сервисам.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `service_id` | BIGINT | FK на services | NOT NULL |
| `environment_id` | BIGINT | FK на service_environments | NULL |
| `allowed_days` | VARCHAR(50) | Разрешённые дни (Mon,Tue,Wed,Thu,Fri) | NULL |
| `allowed_hours` | VARCHAR(100) | Разрешённые часы (09:00-18:00) | NULL |
| `blackout_dates` | JSONB | Запрещённые даты | NULL |
| `max_deploys_per_day` | INTEGER | Лимит деплоев в день | NULL |
| `is_active` | BOOLEAN | Активно ли правило | DEFAULT TRUE |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**blackout_dates** (пример):
```json
["2024-12-31", "2025-01-01", "2025-05-01"]
```

**Индексы**:
- `PRIMARY KEY (id)`
- `INDEX (service_id, is_active)`
- `INDEX (environment_id)`
- `FOREIGN KEY (service_id) REFERENCES services(id) ON DELETE CASCADE`
- `FOREIGN KEY (environment_id) REFERENCES service_environments(id) ON DELETE CASCADE`

---

## 10. API Tokens

### Таблица: `personal_access_tokens` (Laravel Sanctum)
API токены для внешних интеграций.

| Поле | Тип | Описание | Ограничения |
|------|-----|----------|-------------|
| `id` | BIGSERIAL | PK | PRIMARY KEY |
| `tokenable_type` | VARCHAR(255) | Тип модели (User) | NOT NULL |
| `tokenable_id` | BIGINT | ID модели | NOT NULL |
| `name` | VARCHAR(255) | Название токена | NOT NULL |
| `token` | VARCHAR(64) | Хеш токена | UNIQUE, NOT NULL |
| `abilities` | TEXT | Разрешения токена (JSON) | NULL |
| `last_used_at` | TIMESTAMP | Последнее использование | NULL |
| `expires_at` | TIMESTAMP | Дата истечения | NULL |
| `created_at` | TIMESTAMP | Дата создания | NOT NULL |
| `updated_at` | TIMESTAMP | Дата изменения | NOT NULL |

**Индексы**:
- `PRIMARY KEY (id)`
- `UNIQUE INDEX (token)`
- `INDEX (tokenable_type, tokenable_id)`

---

## Диаграмма связей (ER Diagram)

```
users ─┬─── model_has_roles ─── roles ─── role_has_permissions ─── permissions
       ├─── model_has_permissions ────────────────────────────────┘
       ├─── team_user ─── teams ─┬─── services ─┬─── service_environments
       │                          │              ├─── releases ─┬─── release_merge_requests
       │                          │              │              ├─── release_risk_factors ─── risk_factors
       │                          │              │              ├─── release_checklists ─── checklist_templates
       │                          │              │              ├─── release_deployment_rules
       │                          │              │              ├─── release_notifications
       │                          │              │              ├─── release_deployments
       │                          │              │              └─── release_changelog
       │                          │              │
       │                          │              └─── incidents ─── incident_changelog
       │                          │
       │                          └─── notification_channels ─── notification_logs
       │
       └─── personal_access_tokens

integrations
deployment_schedules
release_templates
```

---

## Миграции — порядок выполнения

1. `users`
2. `roles`, `permissions`, `model_has_roles`, `model_has_permissions`, `role_has_permissions`
3. `teams`, `team_user`
4. `services`, `service_environments`
5. `risk_factors`
6. `release_templates`, `checklist_templates`
7. `releases`
8. `release_merge_requests`
9. `release_risk_factors`
10. `release_checklists`
11. `release_deployment_rules`
12. `release_notifications`
13. `release_deployments`
14. `release_changelog`
15. `incidents`, `incident_changelog`
16. `integrations`
17. `notification_channels`, `notification_logs`
18. `deployment_schedules`
19. `personal_access_tokens`

---

## Рекомендации по оптимизации

### Индексы
- Все внешние ключи индексированы
- Индексы на поля фильтрации (`status`, `is_active`, `created_at`)
- Составные индексы для частых запросов (`service_id + status`, `team_id + is_active`)

### Партиционирование (для больших данных)
- `release_changelog` — по дате (ежемесячное или ежегодное)
- `notification_logs` — по дате (ежемесячное)
- `release_deployments` — по дате (ежеквартальное)

### Кэширование
- Списки ролей и разрешений (Spatie Permission автоматически кэширует)
- Справочник факторов риска (редко меняется)
- Шаблоны релизов и чеклистов
- Настройки команд и сервисов

### Очистка данных
- Архивирование старых записей `notification_logs` (>6 месяцев)
- Soft delete для `releases`, `incidents`, `services` с возможностью восстановления
- Периодическая очистка истории изменений (опционально, по retention policy)

---

**Дата создания**: 2026-03-14  
**Версия**: 1.0  
**Статус**: Draft
