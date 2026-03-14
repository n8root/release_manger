# Инструкции для Copilot

## Быстрая настройка

Проект использует Laravel Sail для Docker-окружения. Для быстрой настройки запусти контейнер:

```bash
sail up -d
sail php artisan key:generate --force
sail php artisan optimize
sail php artisan migrate --seed
sail npm run build
```

Это запустит Docker-контейнеры, сгенерирует ключ приложения, оптимизирует конфигурацию, запустит миграции с начальными данными и соберёт фронтенд.

## Спецификации

По каждой фиче пиши небольшую документацию спецификацию в папке specifications

## Спецификации

Документируй каждый эндпоинт в swagger

## Сборка, тестирование и линтинг

### Запуск тестов

**Запустить юнит-тесты:**
```bash
sail artisan test --testsuite=Unit --testdox
```

**Запустить Feature-тесты:**
```bash
sail artisan test --testsuite=Feature --testdox
```

**Запустить определённый файл тестов:**
```bash
sail artisan test tests/Feature/ProfileTest.php
```

**Запустить тесты с покрытием кода:**
```bash
sail artisan test --coverage --min=80
```

**Запустить конкретный тест по имени:**
```bash
sail artisan test --filter="может обновить профиль"
```

Фреймворк тестирования — **Pest** (современная обёртка PHPUnit с выразительным синтаксисом). Файлы тестов используют функциональный синтаксис без классов:
```php
test('описание теста', function () {
    expect($value)->toBe($expected);
});

it('должен выполнить действие', function () {
    // тестовая логика
});
```

### Линтинг и стиль кода

**Запустить Pint (форматер Laravel):**
```bash
sail vendor/bin/pint
```

**Проверить стиль без изменений:**
```bash
sail vendor/bin/pint --test
```

**Форматировать конкретную директорию:**
```bash
sail vendor/bin/pint app/Actions
```

Pint автоматически применяет стиль PSR-12 и соглашения Laravel.

### Pre-commit хуки

Проект использует Git хуки для автоматической проверки перед коммитом:
- Запуск Pint для форматирования кода
- Запуск тестов (только затронутые файлы)
- Проверка синтаксических ошибок

Убедитесь, что хуки установлены:
```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
```

## Архитектура

### Общие правила работы

- **Двойное затруднение:** Если спотыкаешься больше двух раз, спрашивай меня, стоит ли дальше продолжать
- **Сохранность данных:** Не удалять никакие файлы без моего разрешения
- **Контроль версий:** Каждая фича/исправление — отдельный коммит в репозиторий (с моего разрешения, даже в режиме автопилота)
- **Хирургическая точность:** Если в файле нужно исправить только пару строк кода, не генерируй весь файл заново
- **Продакшн-качество:** Это production-решение, упор на надёжности и поддерживаемости
- **Явное лучше неявного:** Избегай магии Laravel, где это возможно (например, предпочитай явное внедрение зависимостей)

### Стек технологий

- **Бэкенд:** Laravel 12 с Inertia.js для серверного рендеринга
- **Фронтенд:** Vue 3 (Composition API) с Tailwind CSS 4
- **База данных:** PostgreSQL (основная БД для production)
- **Аутентификация:** Laravel Sanctum для API + сессии для web
- **Авторизация:** Spatie Laravel Permission (роли и разрешения)
- **DTO:** Spatie Laravel Data (строгая типизация данных)
- **Сборщик:** Vite для бандлирования и горячей перезагрузки
- **Задачи/Очереди:** Redis для очередей в production, sync для тестирования
- **Тестирование:** Pest PHP
- **Контейнеризация:** Laravel Sail (Docker)
- **Документирование:** Swagger

### Архитектурные принципы

Проект использует **Event-Driven Architecture** с чистой архитектурой:

1. **Controllers** — тонкий слой маршрутизации
2. **Actions** — бизнес-логика (один класс = одно действие)
3. **Events** — события для асинхронной обработки
4. **Listeners** — обработчики событий
5. **DTOs** — строгая типизация данных (Spatie Laravel Data)
6. **Models** — только доступ к данным, без бизнес-логики

**Поток обработки запроса:**
```
Request → FormRequest (валидация) → Controller → Action → Model/Repository
                ↓
              DTO
                ↓
           Events/Jobs (опционально)
                ↓
           Response (Inertia/JSON)
```

### Ключевые директории

```
app/
├── Actions/              # Бизнес-логика (один класс = одно действие)
├── Data/                 # DTOs (Spatie Laravel Data)
├── Events/               # События приложения
├── Exceptions/           # Кастомные исключения с Responsable
├── Http/
│   ├── Controllers/      # Контроллеры (тонкий слой)
│   ├── Middleware/       # Middleware
│   └── Requests/         # Form Requests с валидацией
├── Listeners/            # Обработчики событий
├── Models/               # Eloquent модели (только данные)
├── Policies/             # Политики авторизации (если не используется Spatie Permission)
└── Providers/            # Service Providers

resources/
├── js/
│   ├── Components/       # Переиспользуемые Vue компоненты
│   ├── Composables/      # Vue composables (shared logic)
│   ├── Layouts/          # Layout компоненты
│   ├── Pages/            # Страницы Inertia.js
│   ├── Stores/           # Pinia stores (state management)
│   └── Utils/            # Утилиты и хелперы
└── css/
    └── app.css           # Tailwind и глобальные стили

tests/
├── Feature/              # Интеграционные тесты
├── Unit/                 # Юнит-тесты
└── Pest.php              # Pest конфигурация
```

### Поток рендеринга страницы (Inertia.js)

1. **Routes** (`routes/web.php`) определяют эндпоинты
2. **Middleware** проверяет аутентификацию и авторизацию
3. **Controllers** получают запрос, вызывают Action
4. **Actions** выполняют бизнес-логику, возвращают DTO
5. **Controllers** возвращают `Inertia::render()` с пропсами
6. **Vue Components** (`resources/js/Pages/`) получают props и рендерят HTML
7. **Tailwind CSS** стилизует компоненты
8. **Vite** обрабатывает и hot-reload во время разработки

Пример полного потока:
```php
// routes/web.php
Route::post('/releases', [ReleaseController::class, 'store'])
    ->middleware(['auth', 'permission:create-releases']);

// app/Http/Controllers/ReleaseController.php
public function store(CreateReleaseRequest $request): RedirectResponse
{
    $action = app(CreateReleaseAction::class);
    $release = $action->handle($request->toDto());
    
    return redirect()->route('releases.show', $release->id)
        ->with('success', 'Релиз успешно создан');
}

// app/Http/Requests/CreateReleaseRequest.php
public function rules(): array
{
    return [
        'name' => 'required|string|max:255',
        'version' => 'required|string|regex:/^\d+\.\d+\.\d+$/',
        'releaseDate' => 'required|date|after:today',
    ];
}

public function toDto(): CreateReleaseData
{
    return CreateReleaseData::from($this->validated());
}

// app/Data/CreateReleaseData.php (Spatie Laravel Data)
use Spatie\LaravelData\Data;

class CreateReleaseData extends Data
{
    public function __construct(
        public string $name,
        public string $version,
        public Carbon $releaseDate,
    ) {}
}

// app/Actions/CreateReleaseAction.php
class CreateReleaseAction
{
    public function handle(CreateReleaseData $data): Release
    {
        $release = Release::create([
            'name' => $data->name,
            'version' => $data->version,
            'release_date' => $data->releaseDate,
        ]);
        
        event(new ReleaseCreated($release));
        
        return $release;
    }
}
```

### Аутентификация и авторизация

#### Spatie Laravel Permission (СТАНДАРТ)

**Всегда используй Spatie Laravel Permission** для управления ролями и разрешениями. Это единственный стандарт в проекте.

**Базовые концепции:**
- **Roles** (роли) — группы разрешений (admin, manager, user)
- **Permissions** (разрешения) — конкретные действия (create-releases, delete-users, view-reports)
- Роли и разрешения хранятся в БД и управляются через админку
- Поддержка guard-based разрешений (web, api)

**Назначение ролей и разрешений:**
```php
// Создание роли и разрешений (в сидере)
$role = Role::create(['name' => 'release-manager']);
$permission = Permission::create(['name' => 'create-releases']);

$role->givePermissionTo($permission);
$role->givePermissionTo(['edit-releases', 'delete-releases']);

// Назначение роли пользователю
$user->assignRole('release-manager');
$user->assignRole(['release-manager', 'content-editor']);

// Прямое назначение разрешения
$user->givePermissionTo('edit-releases');

// Удаление роли/разрешения
$user->removeRole('release-manager');
$user->revokePermissionTo('edit-releases');
```

**Проверка разрешений в коде:**
```php
// В контроллере через middleware
Route::post('/releases', [ReleaseController::class, 'store'])
    ->middleware('permission:create-releases');

Route::group(['middleware' => ['role:admin']], function () {
    // только для админов
});

Route::group(['middleware' => ['permission:create-releases|edit-releases']], function () {
    // любое из разрешений (OR)
});

// Проверка в коде
if ($user->hasPermissionTo('edit-releases')) {
    // действие
}

if ($user->hasRole('admin')) {
    // действие
}

if ($user->hasAnyRole(['admin', 'release-manager'])) {
    // действие
}

if ($user->hasAllRoles(['admin', 'super-admin'])) {
    // действие
}

// В Blade/Inertia props
@can('edit-releases')
    // показать UI
@endcan

// Передача в Inertia
return Inertia::render('Releases/Index', [
    'canCreateReleases' => auth()->user()->can('create-releases'),
    'isAdmin' => auth()->user()->hasRole('admin'),
]);
```

**Проверка разрешений в политиках (если нужна сложная логика):**
```php
// app/Policies/ReleasePolicy.php
class ReleasePolicy
{
    public function update(User $user, Release $release): bool
    {
        // Комбинация разрешений и бизнес-логики
        return $user->hasPermissionTo('edit-releases') 
            && ($user->id === $release->author_id || $user->hasRole('admin'));
    }
    
    public function delete(User $user, Release $release): bool
    {
        return $user->hasPermissionTo('delete-releases')
            && $release->status !== ReleaseStatus::Published;
    }
}

// Использование в контроллере
$this->authorize('update', $release);
```

**Кэширование разрешений:**
Spatie Permission автоматически кэширует разрешения. Сброс кэша:
```php
// После изменения разрешений
app()[\Spatie\Permission\PermissionRegistrar::class]->forgetCachedPermissions();

// Или через artisan
sail artisan permission:cache-reset
```

#### Laravel Sanctum (API)

Используется только для API аутентификации:
```php
// Выдача токена
$token = $user->createToken('api-token')->plainTextToken;

// Защита маршрутов
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/user', fn() => auth()->user());
});
```

### База данных

- Использует **Eloquent ORM** для простых запросов и доступа к данным
- Для сложных и тяжёлых запросов используй **нативные SQL запросы** через `DB::select()`
- Миграции в `database/migrations/` с понятными именами
- Фабрики для тестовых данных в `database/factories/`
- Основная БД — **PostgreSQL** (production), SQLite для тестов

**Правила работы с БД:**
```php
// ✅ Хорошо: простой запрос через Eloquent
$users = User::where('active', true)->with('roles')->get();

// ✅ Хорошо: сложный запрос через Query Builder с индексами
$releases = DB::table('releases')
    ->join('projects', 'releases.project_id', '=', 'projects.id')
    ->select('releases.*', 'projects.name as project_name')
    ->where('releases.status', 'published')
    ->orderBy('releases.created_at', 'desc')
    ->get();

// ✅ Хорошо: тяжёлый запрос через нативный SQL
$stats = DB::select('
    SELECT 
        p.id,
        p.name,
        COUNT(r.id) as releases_count,
        AVG(r.downloads) as avg_downloads
    FROM projects p
    LEFT JOIN releases r ON p.id = r.project_id
    WHERE p.created_at > ?
    GROUP BY p.id, p.name
    HAVING COUNT(r.id) > 5
    ORDER BY avg_downloads DESC
', [now()->subYear()]);

// ❌ Плохо: N+1 проблема
foreach (User::all() as $user) {
    echo $user->roles; // запрос на каждой итерации
}

// ✅ Хорошо: eager loading
foreach (User::with('roles')->get() as $user) {
    echo $user->roles; // один запрос
}
```

**Миграции — именование и структура:**
```php
// database/migrations/2024_01_15_create_releases_table.php
public function up(): void
{
    Schema::create('releases', function (Blueprint $table) {
        $table->id();
        $table->foreignId('project_id')->constrained()->cascadeOnDelete();
        $table->string('name');
        $table->string('version')->unique();
        $table->text('description')->nullable();
        $table->enum('status', ['draft', 'published', 'archived'])->default('draft');
        $table->timestamp('release_date')->nullable();
        $table->timestamps();
        $table->softDeletes();
        
        // Индексы для производительности
        $table->index(['status', 'release_date']);
        $table->index('created_at');
    });
}
```

## Стандарты разработки бэкенда

### Использование Spatie Laravel Data (DTO) — СТАНДАРТ

**Всегда используй Spatie Laravel Data** для передачи данных между слоями приложения. Это обеспечивает строгую типизацию и валидацию.

**Базовые принципы:**
- Все данные между слоями передаются через DTO
- DTO неизменяемы (immutable)
- Валидация на уровне FormRequest, DTO только для типизации
- Используй camelCase для свойств DTO (PHP convention в этом проекте)
- Автоматическое преобразование snake_case → camelCase при маппинге

**Создание DTO:**
```php
// app/Data/ReleaseData.php
namespace App\Data;

use Carbon\Carbon;
use Spatie\LaravelData\Attributes\MapInputName;
use Spatie\LaravelData\Data;
use Spatie\LaravelData\Mappers\SnakeCaseMapper;

#[MapInputName(SnakeCaseMapper::class)] // автоматический маппинг snake_case
class ReleaseData extends Data
{
    public function __construct(
        public ?int $id,
        public string $name,
        public string $version,
        public string $description,
        public ReleaseStatus $status,
        public ?Carbon $releaseDate,
        public ProjectData $project, // вложенный DTO
        public int $downloadsCount,
    ) {}
}
```

**Использование с Eloquent моделями:**
```php
// Из модели в DTO
$releaseData = ReleaseData::from($release);

// Из массива в DTO
$releaseData = ReleaseData::from([
    'name' => 'v1.0.0',
    'version' => '1.0.0',
    'release_date' => now(), // автоматически snake_case → camelCase
]);

// Из DTO в модель (только для создания/обновления)
$release = Release::create($releaseData->toArray());
$release->update($releaseData->only('name', 'version')->toArray());
```

**Коллекции DTO:**
```php
// app/Data/ReleaseListData.php
use Spatie\LaravelData\DataCollection;

class ReleaseListData extends Data
{
    public function __construct(
        /** @var DataCollection<ReleaseData> */
        public DataCollection $releases,
        public int $total,
        public int $perPage,
    ) {}
}

// Использование
$data = ReleaseListData::from([
    'releases' => Release::with('project')->paginate(15),
    'total' => Release::count(),
    'per_page' => 15,
]);
```

**DTO с валидацией (опционально, предпочтительнее FormRequest):**
```php
use Spatie\LaravelData\Attributes\Validation\Required;
use Spatie\LaravelData\Attributes\Validation\Max;

class CreateReleaseData extends Data
{
    public function __construct(
        #[Required, Max(255)]
        public string $name,
        
        #[Required, Regex('/^\d+\.\d+\.\d+$/')]
        public string $version,
    ) {}
    
    // Если нужна кастомная валидация
    public static function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'version' => ['required', 'regex:/^\d+\.\d+\.\d+$/'],
        ];
    }
}
```

**Трансформация данных:**
```php
class ReleaseData extends Data
{
    public function __construct(
        public string $name,
        public string $version,
        public Carbon $releaseDate,
    ) {}
    
    // Кастомный маппинг для frontend (camelCase)
    public function toFrontend(): array
    {
        return [
            'name' => $this->name,
            'version' => $this->version,
            'releaseDate' => $this->releaseDate->toIso8601String(),
            'isPublished' => $this->status === ReleaseStatus::Published,
        ];
    }
}
```

**Partial DTO (для обновлений):**
```php
// Опциональные поля для PATCH запросов
use Spatie\LaravelData\Optional;

class UpdateReleaseData extends Data
{
    public function __construct(
        public string|Optional $name,
        public string|Optional $version,
        public string|Optional $description,
        public ReleaseStatus|Optional $status,
    ) {}
}

// В контроллере
public function update(UpdateReleaseRequest $request, Release $release)
{
    $data = UpdateReleaseData::from($request->validated());
    $release->update($data->toArray()); // обновит только переданные поля
}
```

### API Документация через Swagger (darkaonline/l5-swagger) — СТАНДАРТ

**Всегда документируй REST API через аннотации OpenAPI 3.0** прямо в контроллерах. Используй пакет `darkaonline/l5-swagger`.

#### Установка и настройка

```bash
sail composer require darkaonline/l5-swagger
sail artisan vendor:publish --provider "L5Swagger\L5SwaggerServiceProvider"
sail artisan l5-swagger:generate
```

Конфигурация в `config/l5-swagger.php`:
```php
'defaults' => [
    'routes' => [
        'api' => 'api/documentation',
    ],
    'paths' => [
        'docs' => storage_path('api-docs'),
        'annotations' => [
            base_path('app/Http/Controllers/Api'),
        ],
    ],
],
```

#### Общая информация API (в базовом контроллере)

```php
// app/Http/Controllers/Api/Controller.php
namespace App\Http\Controllers\Api;

/**
 * @OA\Info(
 *     version="1.0.0",
 *     title="Release Manager API",
 *     description="API для управления релизами",
 *     @OA\Contact(
 *         email="api@example.com"
 *     ),
 *     @OA\License(
 *         name="MIT",
 *         url="https://opensource.org/licenses/MIT"
 *     )
 * )
 *
 * @OA\Server(
 *     url="/api",
 *     description="API Server"
 * )
 *
 * @OA\SecurityScheme(
 *     securityScheme="bearerAuth",
 *     type="http",
 *     scheme="bearer",
 *     bearerFormat="JWT",
 *     description="Используй токен из Laravel Sanctum"
 * )
 *
 * @OA\Tag(
 *     name="Releases",
 *     description="Управление релизами"
 * )
 *
 * @OA\Tag(
 *     name="Services",
 *     description="Управление сервисами"
 * )
 */
abstract class Controller
{
    //
}
```

#### Документирование GET эндпоинтов

```php
namespace App\Http\Controllers\Api;

use App\Actions\GetReleasesListAction;
use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

class ReleaseController extends Controller
{
    /**
     * @OA\Get(
     *     path="/releases",
     *     summary="Получить список релизов",
     *     description="Возвращает список релизов с пагинацией и фильтрацией",
     *     operationId="getReleases",
     *     tags={"Releases"},
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="page",
     *         in="query",
     *         description="Номер страницы",
     *         required=false,
     *         @OA\Schema(type="integer", default=1, minimum=1)
     *     ),
     *     @OA\Parameter(
     *         name="per_page",
     *         in="query",
     *         description="Количество элементов на странице",
     *         required=false,
     *         @OA\Schema(type="integer", default=15, minimum=1, maximum=100)
     *     ),
     *     @OA\Parameter(
     *         name="status",
     *         in="query",
     *         description="Фильтр по статусу",
     *         required=false,
     *         @OA\Schema(
     *             type="string",
     *             enum={"draft", "ready", "deployed", "rolled_back"}
     *         )
     *     ),
     *     @OA\Parameter(
     *         name="service_id",
     *         in="query",
     *         description="Фильтр по ID сервиса",
     *         required=false,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Успешный ответ",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean", example=true),
     *             @OA\Property(
     *                 property="data",
     *                 type="object",
     *                 @OA\Property(
     *                     property="releases",
     *                     type="array",
     *                     @OA\Items(ref="#/components/schemas/Release")
     *                 ),
     *                 @OA\Property(property="total", type="integer", example=100),
     *                 @OA\Property(property="per_page", type="integer", example=15),
     *                 @OA\Property(property="current_page", type="integer", example=1),
     *                 @OA\Property(property="last_page", type="integer", example=7)
     *             )
     *         )
     *     ),
     *     @OA\Response(
     *         response=401,
     *         description="Не авторизован",
     *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
     *     ),
     *     @OA\Response(
     *         response=403,
     *         description="Недостаточно прав",
     *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
     *     )
     * )
     */
    public function index(): JsonResponse
    {
        $action = app(GetReleasesListAction::class);
        $releases = $action->handle();
        
        return response()->json([
            'success' => true,
            'data' => $releases,
        ]);
    }
    
    /**
     * @OA\Get(
     *     path="/releases/{id}",
     *     summary="Получить релиз по ID",
     *     description="Возвращает детальную информацию о релизе",
     *     operationId="getReleaseById",
     *     tags={"Releases"},
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(
     *         name="id",
     *         in="path",
     *         description="ID релиза",
     *         required=true,
     *         @OA\Schema(type="integer")
     *     ),
     *     @OA\Response(
     *         response=200,
     *         description="Успешный ответ",
     *         @OA\JsonContent(
     *             @OA\Property(property="success", type="boolean", example=true),
     *             @OA\Property(property="data", ref="#/components/schemas/ReleaseDetailed")
     *         )
     *     ),
     *     @OA\Response(
     *         response=404,
     *         description="Релиз не найден",
     *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
     *     )
     * )
     */
    public function show(int $id): JsonResponse
    {
        // реализация
    }
}
```

#### Документирование POST эндпоинтов

```php
/**
 * @OA\Post(
 *     path="/releases",
 *     summary="Создать новый релиз",
 *     description="Создаёт новый релиз в статусе 'draft'",
 *     operationId="createRelease",
 *     tags={"Releases"},
 *     security={{"bearerAuth":{}}},
 *     @OA\RequestBody(
 *         required=true,
 *         description="Данные для создания релиза",
 *         @OA\JsonContent(ref="#/components/schemas/CreateReleaseRequest")
 *     ),
 *     @OA\Response(
 *         response=201,
 *         description="Релиз успешно создан",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="data", ref="#/components/schemas/Release"),
 *             @OA\Property(property="message", type="string", example="Релиз успешно создан")
 *         )
 *     ),
 *     @OA\Response(
 *         response=422,
 *         description="Ошибка валидации",
 *         @OA\JsonContent(ref="#/components/schemas/ValidationErrorResponse")
 *     ),
 *     @OA\Response(
 *         response=403,
 *         description="Недостаточно прав",
 *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
 *     )
 * )
 */
public function store(CreateReleaseRequest $request): JsonResponse
{
    $action = app(CreateReleaseAction::class);
    $release = $action->handle($request->toDto());
    
    return response()->json([
        'success' => true,
        'data' => $release,
        'message' => 'Релиз успешно создан',
    ], 201);
}
```

#### Документирование PUT/PATCH эндпоинтов

```php
/**
 * @OA\Put(
 *     path="/releases/{id}",
 *     summary="Обновить релиз",
 *     description="Обновляет данные существующего релиза",
 *     operationId="updateRelease",
 *     tags={"Releases"},
 *     security={{"bearerAuth":{}}},
 *     @OA\Parameter(
 *         name="id",
 *         in="path",
 *         description="ID релиза",
 *         required=true,
 *         @OA\Schema(type="integer")
 *     ),
 *     @OA\RequestBody(
 *         required=true,
 *         @OA\JsonContent(ref="#/components/schemas/UpdateReleaseRequest")
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Релиз успешно обновлён",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="data", ref="#/components/schemas/Release"),
 *             @OA\Property(property="message", type="string", example="Релиз обновлён")
 *         )
 *     ),
 *     @OA\Response(
 *         response=404,
 *         description="Релиз не найден",
 *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
 *     ),
 *     @OA\Response(
 *         response=422,
 *         description="Ошибка валидации",
 *         @OA\JsonContent(ref="#/components/schemas/ValidationErrorResponse")
 *     )
 * )
 */
public function update(UpdateReleaseRequest $request, Release $release): JsonResponse
{
    $action = app(UpdateReleaseAction::class);
    $action->handle($release, $request->toDto());
    
    return response()->json([
        'success' => true,
        'data' => $release->fresh(),
        'message' => 'Релиз обновлён',
    ]);
}
```

#### Документирование DELETE эндпоинтов

```php
/**
 * @OA\Delete(
 *     path="/releases/{id}",
 *     summary="Удалить релиз",
 *     description="Удаляет релиз (soft delete)",
 *     operationId="deleteRelease",
 *     tags={"Releases"},
 *     security={{"bearerAuth":{}}},
 *     @OA\Parameter(
 *         name="id",
 *         in="path",
 *         description="ID релиза",
 *         required=true,
 *         @OA\Schema(type="integer")
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Релиз успешно удалён",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(property="message", type="string", example="Релиз удалён")
 *         )
 *     ),
 *     @OA\Response(
 *         response=404,
 *         description="Релиз не найден",
 *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
 *     ),
 *     @OA\Response(
 *         response=403,
 *         description="Недостаточно прав",
 *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
 *     ),
 *     @OA\Response(
 *         response=409,
 *         description="Невозможно удалить (конфликт состояния)",
 *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
 *     )
 * )
 */
public function destroy(Release $release): JsonResponse
{
    $release->delete();
    
    return response()->json([
        'success' => true,
        'message' => 'Релиз удалён',
    ]);
}
```

#### Документирование кастомных действий

```php
/**
 * @OA\Post(
 *     path="/releases/{id}/deploy",
 *     summary="Задеплоить релиз",
 *     description="Запускает процесс деплоя релиза",
 *     operationId="deployRelease",
 *     tags={"Releases"},
 *     security={{"bearerAuth":{}}},
 *     @OA\Parameter(
 *         name="id",
 *         in="path",
 *         description="ID релиза",
 *         required=true,
 *         @OA\Schema(type="integer")
 *     ),
 *     @OA\RequestBody(
 *         required=false,
 *         @OA\JsonContent(
 *             @OA\Property(
 *                 property="environment_id",
 *                 type="integer",
 *                 description="ID окружения для деплоя",
 *                 example=1
 *             )
 *         )
 *     ),
 *     @OA\Response(
 *         response=200,
 *         description="Деплой запущен",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=true),
 *             @OA\Property(
 *                 property="data",
 *                 type="object",
 *                 @OA\Property(property="deployment_id", type="integer", example=123),
 *                 @OA\Property(property="status", type="string", example="pending"),
 *                 @OA\Property(property="pipeline_url", type="string", example="https://...")
 *             ),
 *             @OA\Property(property="message", type="string", example="Деплой запущен")
 *         )
 *     ),
 *     @OA\Response(
 *         response=403,
 *         description="Недостаточно прав для деплоя",
 *         @OA\JsonContent(ref="#/components/schemas/ErrorResponse")
 *     ),
 *     @OA\Response(
 *         response=409,
 *         description="Релиз не готов к деплою",
 *         @OA\JsonContent(
 *             @OA\Property(property="success", type="boolean", example=false),
 *             @OA\Property(
 *                 property="error",
 *                 type="object",
 *                 @OA\Property(property="code", type="integer", example=2002),
 *                 @OA\Property(property="message", type="string", example="Релиз не готов к деплою"),
 *                 @OA\Property(
 *                     property="details",
 *                     type="object",
 *                     @OA\Property(property="status", type="string", example="draft"),
 *                     @OA\Property(
 *                         property="missing_checks",
 *                         type="array",
 *                         @OA\Items(type="string", example="Тесты не пройдены")
 *                     )
 *                 )
 *             )
 *         )
 *     )
 * )
 */
public function deploy(DeployReleaseRequest $request, Release $release): JsonResponse
{
    $action = app(DeployReleaseAction::class);
    $deployment = $action->handle($release, $request->toDto());
    
    return response()->json([
        'success' => true,
        'data' => $deployment,
        'message' => 'Деплой запущен',
    ]);
}
```

#### Схемы данных (Schemas)

Создай отдельный файл для схем в `app/Http/Controllers/Api/Schemas/`:

```php
// app/Http/Controllers/Api/Schemas/ReleaseSchemas.php
namespace App\Http\Controllers\Api\Schemas;

/**
 * @OA\Schema(
 *     schema="Release",
 *     title="Release",
 *     description="Модель релиза",
 *     required={"id", "name", "version", "status"},
 *     @OA\Property(property="id", type="integer", example=1),
 *     @OA\Property(property="service_id", type="integer", example=5),
 *     @OA\Property(property="name", type="string", example="Release v1.0.0"),
 *     @OA\Property(property="version", type="string", example="1.0.0"),
 *     @OA\Property(property="description", type="string", example="Описание релиза"),
 *     @OA\Property(
 *         property="status",
 *         type="string",
 *         enum={"draft", "ready", "deploying", "deployed", "rolled_back"},
 *         example="draft"
 *     ),
 *     @OA\Property(property="planned_at", type="string", format="date-time", example="2024-03-15T10:00:00Z"),
 *     @OA\Property(property="deployed_at", type="string", format="date-time", nullable=true),
 *     @OA\Property(property="responsible_user_id", type="integer", nullable=true, example=10),
 *     @OA\Property(property="created_at", type="string", format="date-time", example="2024-03-14T12:00:00Z"),
 *     @OA\Property(property="updated_at", type="string", format="date-time", example="2024-03-14T12:30:00Z")
 * )
 */
class ReleaseSchemas {}

/**
 * @OA\Schema(
 *     schema="ReleaseDetailed",
 *     title="Release Detailed",
 *     description="Детальная модель релиза с отношениями",
 *     allOf={
 *         @OA\Schema(ref="#/components/schemas/Release"),
 *         @OA\Schema(
 *             @OA\Property(
 *                 property="service",
 *                 ref="#/components/schemas/Service"
 *             ),
 *             @OA\Property(
 *                 property="responsible_user",
 *                 ref="#/components/schemas/User"
 *             ),
 *             @OA\Property(
 *                 property="merge_requests",
 *                 type="array",
 *                 @OA\Items(ref="#/components/schemas/MergeRequest")
 *             ),
 *             @OA\Property(
 *                 property="risk_factors",
 *                 type="array",
 *                 @OA\Items(ref="#/components/schemas/RiskFactor")
 *             ),
 *             @OA\Property(
 *                 property="checklist",
 *                 type="array",
 *                 @OA\Items(ref="#/components/schemas/ChecklistItem")
 *             )
 *         )
 *     }
 * )
 */
class ReleaseDetailedSchemas {}

/**
 * @OA\Schema(
 *     schema="CreateReleaseRequest",
 *     title="Create Release Request",
 *     description="Данные для создания релиза",
 *     required={"name", "version", "service_id"},
 *     @OA\Property(property="name", type="string", maxLength=255, example="Release v1.0.0"),
 *     @OA\Property(property="version", type="string", pattern="^\d+\.\d+\.\d+$", example="1.0.0"),
 *     @OA\Property(property="service_id", type="integer", example=5),
 *     @OA\Property(property="description", type="string", maxLength=5000, nullable=true, example="Новые функции и исправления"),
 *     @OA\Property(property="planned_at", type="string", format="date-time", example="2024-03-20T10:00:00Z"),
 *     @OA\Property(property="environment_id", type="integer", nullable=true, example=1),
 *     @OA\Property(property="responsible_user_id", type="integer", nullable=true, example=10)
 * )
 */
class CreateReleaseRequestSchemas {}

/**
 * @OA\Schema(
 *     schema="UpdateReleaseRequest",
 *     title="Update Release Request",
 *     description="Данные для обновления релиза (все поля опциональны)",
 *     @OA\Property(property="name", type="string", maxLength=255, example="Release v1.0.1"),
 *     @OA\Property(property="version", type="string", pattern="^\d+\.\d+\.\d+$", example="1.0.1"),
 *     @OA\Property(property="description", type="string", maxLength=5000, example="Обновлённое описание"),
 *     @OA\Property(property="planned_at", type="string", format="date-time", example="2024-03-21T10:00:00Z"),
 *     @OA\Property(property="responsible_user_id", type="integer", example=12)
 * )
 */
class UpdateReleaseRequestSchemas {}

/**
 * @OA\Schema(
 *     schema="ErrorResponse",
 *     title="Error Response",
 *     description="Стандартный формат ответа с ошибкой",
 *     @OA\Property(property="success", type="boolean", example=false),
 *     @OA\Property(
 *         property="error",
 *         type="object",
 *         @OA\Property(property="code", type="integer", example=2001),
 *         @OA\Property(property="message", type="string", example="Релиз не найден")
 *     )
 * )
 */
class ErrorResponseSchemas {}

/**
 * @OA\Schema(
 *     schema="ValidationErrorResponse",
 *     title="Validation Error Response",
 *     description="Ответ с ошибками валидации",
 *     @OA\Property(property="success", type="boolean", example=false),
 *     @OA\Property(
 *         property="error",
 *         type="object",
 *         @OA\Property(property="code", type="integer", example=1000),
 *         @OA\Property(property="message", type="string", example="Ошибка валидации"),
 *         @OA\Property(
 *             property="errors",
 *             type="object",
 *             @OA\Property(
 *                 property="version",
 *                 type="array",
 *                 @OA\Items(type="string", example="Версия должна быть в формате X.Y.Z")
 *             ),
 *             @OA\Property(
 *                 property="name",
 *                 type="array",
 *                 @OA\Items(type="string", example="Поле name обязательно")
 *             )
 *         )
 *     )
 * )
 */
class ValidationErrorResponseSchemas {}
```

#### Генерация и просмотр документации

**Генерация Swagger документации:**
```bash
sail artisan l5-swagger:generate
```

**Просмотр документации:**
- Откройте в браузере: `http://localhost/api/documentation`
- Swagger UI позволит тестировать API прямо из браузера

**Автогенерация при изменениях (development):**
```php
// config/l5-swagger.php
'generate_always' => env('L5_SWAGGER_GENERATE_ALWAYS', false),
```

В `.env` для локальной разработки:
```env
L5_SWAGGER_GENERATE_ALWAYS=true
```

#### Правила документирования API

1. **Всегда документируй все публичные API эндпоинты**
2. **Используй теги** для группировки эндпоинтов (Releases, Services, Users)
3. **Документируй все параметры** запроса (query, path, body)
4. **Документируй все возможные ответы** (200, 400, 401, 403, 404, 422, 500)
5. **Используй схемы** для переиспользования структур данных
6. **Добавляй примеры** для каждого поля (`example=...`)
7. **Документируй аутентификацию** (`security={{"bearerAuth":{}}}`)
8. **Указывай ограничения** (min, max, pattern, enum)
9. **Описывай бизнес-логику** в description
10. **Версионируй API** через префиксы (`/api/v1/`, `/api/v2/`)

#### Пример полного контроллера с документацией

```php
namespace App\Http\Controllers\Api\V1;

use App\Actions\CreateReleaseAction;
use App\Actions\GetReleasesListAction;
use App\Http\Controllers\Api\Controller;
use App\Http\Requests\CreateReleaseRequest;
use App\Models\Release;
use Illuminate\Http\JsonResponse;

class ReleaseController extends Controller
{
    public function __construct()
    {
        $this->middleware('auth:sanctum');
        $this->middleware('permission:view-releases')->only(['index', 'show']);
        $this->middleware('permission:create-releases')->only('store');
        $this->middleware('permission:edit-releases')->only('update');
        $this->middleware('permission:delete-releases')->only('destroy');
    }
    
    /**
     * @OA\Get(
     *     path="/v1/releases",
     *     summary="Получить список релизов",
     *     tags={"Releases"},
     *     security={{"bearerAuth":{}}},
     *     @OA\Parameter(name="page", in="query", @OA\Schema(type="integer")),
     *     @OA\Parameter(name="per_page", in="query", @OA\Schema(type="integer")),
     *     @OA\Parameter(name="status", in="query", @OA\Schema(type="string")),
     *     @OA\Response(response=200, description="Успешный ответ")
     * )
     */
    public function index(): JsonResponse
    {
        $action = app(GetReleasesListAction::class);
        $releases = $action->handle();
        
        return response()->json([
            'success' => true,
            'data' => $releases,
        ]);
    }
    
    /**
     * @OA\Post(
     *     path="/v1/releases",
     *     summary="Создать релиз",
     *     tags={"Releases"},
     *     security={{"bearerAuth":{}}},
     *     @OA\RequestBody(required=true, @OA\JsonContent(ref="#/components/schemas/CreateReleaseRequest")),
     *     @OA\Response(response=201, description="Релиз создан"),
     *     @OA\Response(response=422, description="Ошибка валидации")
     * )
     */
    public function store(CreateReleaseRequest $request): JsonResponse
    {
        $action = app(CreateReleaseAction::class);
        $release = $action->handle($request->toDto());
        
        return response()->json([
            'success' => true,
            'data' => $release,
            'message' => 'Релиз создан',
        ], 201);
    }
}
```

## Соглашения кода

### Именование и структура компонентов

- **Controllers:** `{Entity}Controller` (например, `ReleaseController`), в `App\Http\Controllers\`
  - Тонкий слой, только маршрутизация
  - Не содержат бизнес-логики
  - Вызывают Actions для выполнения операций
  
- **Actions:** Одно действие = один класс (например, `CreateReleaseAction`, `GetReleasesListAction`)
  - Содержат всю бизнес-логику
  - Именуются глаголом (Create, Update, Delete, Get, Send, Process)
  - Один публичный метод `handle()`
  - Принимают DTO, возвращают результат
  
- **Requests:** `{Action}{Entity}Request` (например, `CreateReleaseRequest`, `UpdateReleaseRequest`)
  - Содержат правила валидации
  - Метод `toDto()` для преобразования в DTO
  - В `App\Http\Requests\`
  
- **Data (DTOs):** `{Entity}Data` (например, `ReleaseData`, `CreateReleaseData`)
  - Строгая типизация через Spatie Laravel Data
  - Неизменяемые (immutable)
  - camelCase для свойств
  - В `App\Data\`
  
- **Exceptions:** Одно исключение на сущность с фабричными методами
  - Реализуют `Responsable` для API ответов
  - Пример: `ReleaseException::notFound()`, `ReleaseException::alreadyPublished()`
  - В `App\Exceptions\`
  
- **Events/Listeners:** Отвечают за передачу/обработку асинхронных событий
  - Events: `{Entity}{Action}` (например, `ReleaseCreated`, `ReleasePublished`)
  - Listeners: `{Action}{Entity}Listener` (например, `SendReleaseNotificationListener`)
  - В `App\Events\` и `App\Listeners\`
  
- **Models:** Единственное число, заглавная буква (например, `Release`, `Project`)
  - Только доступ к данным, без бизнес-логики
  - snake_case для полей БД
  - В `App\Models\`
  
- **Vue Components:** PascalCase (например, `ReleaseCard.vue`, `ReleaseForm.vue`)
  - Организованы по функциям в `resources/js/Components/`
  - Страницы в `resources/js/Pages/`
  
- **Migrations:** Timestamped snake_case (генерируются автоматически)
  - `2024_01_15_create_releases_table.php`

### Паттерн Controller + Action

**Controller — тонкий слой:**
```php
namespace App\Http\Controllers;

use App\Actions\CreateReleaseAction;
use App\Http\Requests\CreateReleaseRequest;
use Illuminate\Http\RedirectResponse;
use Inertia\Inertia;
use Inertia\Response;

class ReleaseController extends Controller
{
    public function __construct()
    {
        $this->middleware('permission:create-releases')->only(['create', 'store']);
        $this->middleware('permission:edit-releases')->only(['edit', 'update']);
    }
    
    public function index(): Response
    {
        $action = app(GetReleasesListAction::class);
        $releases = $action->handle();
        
        return Inertia::render('Releases/Index', [
            'releases' => $releases,
            'canCreate' => auth()->user()->can('create-releases'),
        ]);
    }
    
    public function store(CreateReleaseRequest $request): RedirectResponse
    {
        $action = app(CreateReleaseAction::class);
        $release = $action->handle($request->toDto());
        
        return redirect()
            ->route('releases.show', $release->id)
            ->with('success', 'Релиз успешно создан');
    }
    
    public function update(UpdateReleaseRequest $request, Release $release): RedirectResponse
    {
        $this->authorize('update', $release); // если есть сложная логика в Policy
        
        $action = app(UpdateReleaseAction::class);
        $action->handle($release, $request->toDto());
        
        return back()->with('success', 'Релиз обновлён');
    }
}
```

**Action — вся бизнес-логика:**
```php
namespace App\Actions;

use App\Data\CreateReleaseData;
use App\Events\ReleaseCreated;
use App\Exceptions\ReleaseException;
use App\Models\Release;
use Illuminate\Support\Facades\DB;

class CreateReleaseAction
{
    public function handle(CreateReleaseData $data): Release
    {
        // Бизнес-логика и валидация
        if (Release::where('version', $data->version)->exists()) {
            throw ReleaseException::versionAlreadyExists($data->version);
        }
        
        // Транзакция для атомарности
        return DB::transaction(function () use ($data) {
            $release = Release::create([
                'name' => $data->name,
                'version' => $data->version,
                'description' => $data->description,
                'project_id' => $data->projectId,
                'status' => ReleaseStatus::Draft,
                'release_date' => $data->releaseDate,
            ]);
            
            // Дополнительная логика
            $this->createDefaultMilestones($release);
            $this->notifyTeam($release);
            
            // Событие для асинхронной обработки
            event(new ReleaseCreated($release));
            
            return $release->fresh(); // перезагрузить из БД
        });
    }
    
    private function createDefaultMilestones(Release $release): void
    {
        // Вспомогательная логика
    }
    
    private function notifyTeam(Release $release): void
    {
        // Отправка уведомлений
    }
}
```

### Валидация запросов (FormRequest)

Вся валидация находится в **FormRequests**, не в контроллерах или actions:

```php
namespace App\Http\Requests;

use App\Data\CreateReleaseData;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class CreateReleaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        // Базовая авторизация, сложную логику в Policy
        return $this->user()->can('create-releases');
    }
    
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'version' => [
                'required',
                'string',
                'regex:/^\d+\.\d+\.\d+$/',
                Rule::unique('releases', 'version'),
            ],
            'description' => ['nullable', 'string', 'max:5000'],
            'projectId' => ['required', 'integer', Rule::exists('projects', 'id')],
            'releaseDate' => ['required', 'date', 'after:today'],
            'features' => ['nullable', 'array'],
            'features.*' => ['string', 'max:500'],
        ];
    }
    
    public function messages(): array
    {
        return [
            'version.regex' => 'Версия должна быть в формате X.Y.Z (например, 1.0.0)',
            'version.unique' => 'Релиз с такой версией уже существует',
            'releaseDate.after' => 'Дата релиза должна быть в будущем',
        ];
    }
    
    public function attributes(): array
    {
        return [
            'projectId' => 'проект',
            'releaseDate' => 'дата релиза',
        ];
    }
    
    // Преобразование в DTO
    public function toDto(): CreateReleaseData
    {
        return CreateReleaseData::from($this->validated());
    }
}
```

### Обработка ошибок (Exceptions)

**Принципы обработки ошибок:**
- Не используй try/catch в контроллерах
- Все исключения реализуют `Responsable` для автоматического преобразования в HTTP ответ
- Одно исключение на сущность с фабричными методами
- Каждая ошибка имеет уникальный числовой код
- Логируемые ошибки реализуют `Reportable`

**Пример кастомного исключения:**
```php
namespace App\Exceptions;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ReleaseException extends \Exception implements \Illuminate\Contracts\Support\Responsable
{
    private int $errorCode;
    private string $userMessage;
    private bool $shouldReport;
    
    private function __construct(
        string $message,
        int $errorCode,
        string $userMessage,
        int $statusCode = Response::HTTP_BAD_REQUEST,
        bool $shouldReport = false
    ) {
        parent::__construct($message, $statusCode);
        $this->errorCode = $errorCode;
        $this->userMessage = $userMessage;
        $this->shouldReport = $shouldReport;
    }
    
    // Фабричные методы для создания исключений
    public static function notFound(int $id): self
    {
        return new self(
            message: "Release with ID {$id} not found",
            errorCode: 2001,
            userMessage: "Релиз не найден",
            statusCode: Response::HTTP_NOT_FOUND,
            shouldReport: false
        );
    }
    
    public static function alreadyPublished(string $version): self
    {
        return new self(
            message: "Release {$version} is already published",
            errorCode: 2002,
            userMessage: "Релиз уже опубликован и не может быть изменён",
            statusCode: Response::HTTP_CONFLICT,
            shouldReport: false
        );
    }
    
    public static function versionAlreadyExists(string $version): self
    {
        return new self(
            message: "Release version {$version} already exists",
            errorCode: 2003,
            userMessage: "Релиз с такой версией уже существует",
            statusCode: Response::HTTP_CONFLICT,
            shouldReport: false
        );
    }
    
    public static function publishingFailed(\Throwable $e): self
    {
        return new self(
            message: "Failed to publish release: {$e->getMessage()}",
            errorCode: 2100,
            userMessage: "Не удалось опубликовать релиз. Попробуйте позже",
            statusCode: Response::HTTP_INTERNAL_SERVER_ERROR,
            shouldReport: true // логировать критические ошибки
        );
    }
    
    // Автоматическое преобразование в HTTP ответ
    public function toResponse($request): JsonResponse|RedirectResponse
    {
        if ($request->expectsJson() || $request->is('api/*')) {
            return response()->json([
                'success' => false,
                'error' => [
                    'code' => $this->errorCode,
                    'message' => $this->userMessage,
                ],
            ], $this->getCode());
        }
        
        return redirect()
            ->back()
            ->withInput()
            ->withErrors(['error' => $this->userMessage]);
    }
    
    // Логирование критических ошибок
    public function report(): bool
    {
        if ($this->shouldReport) {
            \Log::error($this->getMessage(), [
                'error_code' => $this->errorCode,
                'trace' => $this->getTraceAsString(),
            ]);
        }
        
        return $this->shouldReport;
    }
}
```

**Реестр кодов ошибок** (ведём в комментариях или отдельном файле):
```php
/**
 * Коды ошибок приложения:
 * 
 * 1xxx - Ошибки аутентификации
 * 2xxx - Ошибки работы с релизами
 *   2001 - Релиз не найден
 *   2002 - Релиз уже опубликован
 *   2003 - Версия релиза уже существует
 *   2100 - Критическая ошибка публикации
 * 3xxx - Ошибки работы с проектами
 * 4xxx - Ошибки прав доступа
 */
```

### Eloquent Models — только данные

Модели содержат **только логику доступа к данным**, без бизнес-логики:

```php
namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\SoftDeletes;
use Spatie\Permission\Traits\HasRoles;

class Release extends Model
{
    use HasFactory, SoftDeletes, HasRoles;
    
    protected $fillable = [
        'name',
        'version',
        'description',
        'project_id',
        'status',
        'release_date',
    ];
    
    protected $casts = [
        'release_date' => 'datetime',
        'status' => ReleaseStatus::class, // Enum casting
    ];
    
    // Relationships
    public function project(): BelongsTo
    {
        return $this->belongsTo(Project::class);
    }
    
    public function features(): HasMany
    {
        return $this->hasMany(Feature::class);
    }
    
    // Scopes для переиспользования запросов
    public function scopePublished($query)
    {
        return $query->where('status', ReleaseStatus::Published);
    }
    
    public function scopeUpcoming($query)
    {
        return $query->where('release_date', '>', now())
            ->where('status', ReleaseStatus::Published);
    }
    
    // Accessor для вычисляемых полей (если нужно в модели)
    public function getIsPublishedAttribute(): bool
    {
        return $this->status === ReleaseStatus::Published;
    }
}
```

**Фабрики для тестирования:**
```php
// database/factories/ReleaseFactory.php
namespace Database\Factories;

use App\Models\Project;
use Illuminate\Database\Eloquent\Factories\Factory;

class ReleaseFactory extends Factory
{
    public function definition(): array
    {
        return [
            'name' => $this->faker->words(3, true),
            'version' => $this->faker->semver(),
            'description' => $this->faker->paragraph(),
            'project_id' => Project::factory(),
            'status' => $this->faker->randomElement(ReleaseStatus::cases()),
            'release_date' => $this->faker->dateTimeBetween('now', '+1 year'),
        ];
    }
    
    // State для специфических состояний
    public function published(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => ReleaseStatus::Published,
            'release_date' => now()->subDays(rand(1, 30)),
        ]);
    }
    
    public function draft(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => ReleaseStatus::Draft,
            'release_date' => null,
        ]);
    }
}

// Использование в тестах:
$release = Release::factory()->published()->create();
$releases = Release::factory()->count(10)->create();
```

### Events и Listeners

**Event-Driven Architecture** для асинхронной обработки:

```php
// app/Events/ReleaseCreated.php
namespace App\Events;

use App\Models\Release;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ReleaseCreated
{
    use Dispatchable, InteractsWithSockets, SerializesModels;
    
    public function __construct(public Release $release) {}
}

// app/Listeners/SendReleaseNotificationListener.php
namespace App\Listeners;

use App\Events\ReleaseCreated;
use App\Notifications\NewReleaseNotification;
use Illuminate\Contracts\Queue\ShouldQueue;

class SendReleaseNotificationListener implements ShouldQueue
{
    public function handle(ReleaseCreated $event): void
    {
        $subscribers = $event->release->project->subscribers;
        
        foreach ($subscribers as $subscriber) {
            $subscriber->notify(new NewReleaseNotification($event->release));
        }
    }
}

// Регистрация в EventServiceProvider
protected $listen = [
    ReleaseCreated::class => [
        SendReleaseNotificationListener::class,
        UpdateStatisticsListener::class,
        LogReleaseActivityListener::class,
    ],
];
```

## Лучшие практики Frontend разработки

### Vue 3 Composition API — стандарт проекта

**Всегда используй Composition API с `<script setup>`** для всех компонентов.

**Базовая структура компонента:**
```vue
<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import { useForm, usePage } from '@inertiajs/vue3'

// Props с TypeScript-like типизацией (через JSDoc)
const props = defineProps({
  /** @type {Object} */
  release: {
    type: Object,
    required: true,
  },
  /** @type {Boolean} */
  canEdit: {
    type: Boolean,
    default: false,
  },
})

// Emits для событий
const emit = defineEmits(['updated', 'deleted'])

// Реактивные данные
const isEditing = ref(false)
const localVersion = ref(props.release.version)

// Computed properties
const displayName = computed(() => {
  return `${props.release.name} (v${props.release.version})`
})

const canPublish = computed(() => {
  return props.canEdit && props.release.status === 'draft'
})

// Методы
const startEditing = () => {
  isEditing.value = true
}

const saveChanges = async () => {
  // логика сохранения
  emit('updated', props.release)
  isEditing.value = false
}

// Watchers
watch(() => props.release.version, (newVersion) => {
  localVersion.value = newVersion
})

// Lifecycle hooks
onMounted(() => {
  console.log('Component mounted')
})
</script>

<template>
  <div class="release-card">
    <h3 class="text-xl font-bold">{{ displayName }}</h3>
    
    <div v-if="!isEditing">
      <p class="text-gray-600">{{ release.description }}</p>
      <button 
        v-if="canEdit" 
        @click="startEditing"
        class="btn btn-primary"
      >
        Редактировать
      </button>
    </div>
    
    <form v-else @submit.prevent="saveChanges">
      <!-- форма редактирования -->
    </form>
  </div>
</template>

<style scoped>
.release-card {
  /* scoped стили только для этого компонента */
  padding: 1rem;
  border: 1px solid theme('colors.gray.200');
  border-radius: theme('borderRadius.lg');
}
</style>
```

### Организация компонентов

**Структура директорий:**
```
resources/js/
├── Components/           # Переиспользуемые компоненты
│   ├── Release/
│   │   ├── ReleaseCard.vue
│   │   ├── ReleaseForm.vue
│   │   └── ReleaseList.vue
│   ├── UI/              # UI компоненты (кнопки, инпуты и т.д.)
│   │   ├── Button.vue
│   │   ├── Input.vue
│   │   ├── Modal.vue
│   │   └── Dropdown.vue
│   └── Shared/          # Общие компоненты
│       ├── Header.vue
│       ├── Sidebar.vue
│       └── Pagination.vue
├── Composables/         # Переиспользуемая логика
│   ├── usePermissions.js
│   ├── useToast.js
│   └── useDateFormat.js
├── Layouts/             # Layout компоненты
│   ├── AppLayout.vue
│   ├── AuthLayout.vue
│   └── GuestLayout.vue
├── Pages/               # Страницы (Inertia.js)
│   ├── Releases/
│   │   ├── Index.vue
│   │   ├── Show.vue
│   │   ├── Create.vue
│   │   └── Edit.vue
│   └── Dashboard.vue
├── Stores/              # Pinia stores (если используется)
│   └── releases.js
└── Utils/               # Утилиты
    ├── api.js
    ├── formatters.js
    └── validators.js
```

### Composables — переиспользуемая логика

**Создание composable** для инкапсуляции логики:

```javascript
// resources/js/Composables/usePermissions.js
import { computed } from 'vue'
import { usePage } from '@inertiajs/vue3'

export function usePermissions() {
  const page = usePage()
  
  const user = computed(() => page.props.auth?.user)
  
  const can = (permission) => {
    return user.value?.permissions?.includes(permission) ?? false
  }
  
  const hasRole = (role) => {
    return user.value?.roles?.includes(role) ?? false
  }
  
  const hasAnyRole = (roles) => {
    return roles.some(role => hasRole(role))
  }
  
  return {
    user,
    can,
    hasRole,
    hasAnyRole,
  }
}

// Использование в компоненте
<script setup>
import { usePermissions } from '@/Composables/usePermissions'

const { can, hasRole } = usePermissions()

const canCreateRelease = computed(() => can('create-releases'))
const isAdmin = computed(() => hasRole('admin'))
</script>
```

**Composable для тостов/уведомлений:**
```javascript
// resources/js/Composables/useToast.js
import { ref } from 'vue'

const toasts = ref([])
let nextId = 0

export function useToast() {
  const show = (message, type = 'info', duration = 3000) => {
    const id = nextId++
    const toast = { id, message, type }
    
    toasts.value.push(toast)
    
    if (duration > 0) {
      setTimeout(() => {
        remove(id)
      }, duration)
    }
    
    return id
  }
  
  const remove = (id) => {
    const index = toasts.value.findIndex(t => t.id === id)
    if (index > -1) {
      toasts.value.splice(index, 1)
    }
  }
  
  const success = (message, duration) => show(message, 'success', duration)
  const error = (message, duration) => show(message, 'error', duration)
  const warning = (message, duration) => show(message, 'warning', duration)
  const info = (message, duration) => show(message, 'info', duration)
  
  return {
    toasts,
    show,
    remove,
    success,
    error,
    warning,
    info,
  }
}
```

**Composable для работы с датами:**
```javascript
// resources/js/Composables/useDateFormat.js
import { computed } from 'vue'

export function useDateFormat() {
  const formatDate = (date, format = 'short') => {
    if (!date) return ''
    
    const d = new Date(date)
    
    const formats = {
      short: new Intl.DateTimeFormat('ru-RU').format(d),
      long: new Intl.DateTimeFormat('ru-RU', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      }).format(d),
      time: new Intl.DateTimeFormat('ru-RU', { 
        hour: '2-digit', 
        minute: '2-digit' 
      }).format(d),
      full: new Intl.DateTimeFormat('ru-RU', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      }).format(d),
    }
    
    return formats[format] || formats.short
  }
  
  const timeAgo = (date) => {
    if (!date) return ''
    
    const seconds = Math.floor((new Date() - new Date(date)) / 1000)
    
    const intervals = {
      год: 31536000,
      месяц: 2592000,
      неделя: 604800,
      день: 86400,
      час: 3600,
      минута: 60,
    }
    
    for (const [name, value] of Object.entries(intervals)) {
      const interval = Math.floor(seconds / value)
      if (interval >= 1) {
        return `${interval} ${name}${interval > 1 ? 'а' : ''} назад`
      }
    }
    
    return 'только что'
  }
  
  const isToday = (date) => {
    const d = new Date(date)
    const today = new Date()
    return d.toDateString() === today.toDateString()
  }
  
  const isFuture = (date) => {
    return new Date(date) > new Date()
  }
  
  return {
    formatDate,
    timeAgo,
    isToday,
    isFuture,
  }
}
```

### Inertia.js — работа с формами

**Используй `useForm` от Inertia.js** для всех форм:

```vue
<script setup>
import { useForm } from '@inertiajs/vue3'
import { watch } from 'vue'

const props = defineProps({
  release: Object,
  projects: Array,
})

// Форма с реактивностью и обработкой ошибок
const form = useForm({
  name: props.release?.name ?? '',
  version: props.release?.version ?? '',
  description: props.release?.description ?? '',
  projectId: props.release?.projectId ?? null,
  releaseDate: props.release?.releaseDate ?? '',
})

// Автосохранение (debounced)
let saveTimeout
watch(() => form.data(), () => {
  clearTimeout(saveTimeout)
  saveTimeout = setTimeout(() => {
    form.post('/api/releases/autosave', {
      preserveScroll: true,
      preserveState: true,
    })
  }, 2000)
}, { deep: true })

const submit = () => {
  if (props.release) {
    // Обновление существующего
    form.put(`/releases/${props.release.id}`, {
      onSuccess: () => {
        // Успешное сохранение
        form.reset() // сбросить dirty state
      },
      onError: (errors) => {
        // Ошибки валидации автоматически отобразятся
        console.error('Validation errors:', errors)
      },
    })
  } else {
    // Создание нового
    form.post('/releases', {
      onSuccess: () => {
        // Редирект на страницу релиза произойдёт автоматически
      },
    })
  }
}

// Удаление
const deleteRelease = () => {
  if (confirm('Удалить релиз?')) {
    form.delete(`/releases/${props.release.id}`)
  }
}
</script>

<template>
  <form @submit.prevent="submit">
    <div class="space-y-4">
      <!-- Input с отображением ошибок -->
      <div>
        <label for="name" class="block text-sm font-medium text-gray-700">
          Название релиза
        </label>
        <input
          id="name"
          v-model="form.name"
          type="text"
          class="mt-1 block w-full rounded-md border-gray-300"
          :class="{ 'border-red-500': form.errors.name }"
        />
        <p v-if="form.errors.name" class="mt-1 text-sm text-red-600">
          {{ form.errors.name }}
        </p>
      </div>
      
      <!-- Версия -->
      <div>
        <label for="version" class="block text-sm font-medium text-gray-700">
          Версия
        </label>
        <input
          id="version"
          v-model="form.version"
          type="text"
          placeholder="1.0.0"
          class="mt-1 block w-full rounded-md border-gray-300"
          :class="{ 'border-red-500': form.errors.version }"
        />
        <p v-if="form.errors.version" class="mt-1 text-sm text-red-600">
          {{ form.errors.version }}
        </p>
      </div>
      
      <!-- Select для проекта -->
      <div>
        <label for="project" class="block text-sm font-medium text-gray-700">
          Проект
        </label>
        <select
          id="project"
          v-model="form.projectId"
          class="mt-1 block w-full rounded-md border-gray-300"
          :class="{ 'border-red-500': form.errors.projectId }"
        >
          <option :value="null">Выберите проект</option>
          <option 
            v-for="project in projects" 
            :key="project.id" 
            :value="project.id"
          >
            {{ project.name }}
          </option>
        </select>
        <p v-if="form.errors.projectId" class="mt-1 text-sm text-red-600">
          {{ form.errors.projectId }}
        </p>
      </div>
      
      <!-- Textarea -->
      <div>
        <label for="description" class="block text-sm font-medium text-gray-700">
          Описание
        </label>
        <textarea
          id="description"
          v-model="form.description"
          rows="4"
          class="mt-1 block w-full rounded-md border-gray-300"
          :class="{ 'border-red-500': form.errors.description }"
        />
        <p v-if="form.errors.description" class="mt-1 text-sm text-red-600">
          {{ form.errors.description }}
        </p>
      </div>
      
      <!-- Кнопки -->
      <div class="flex items-center gap-4">
        <button
          type="submit"
          class="btn btn-primary"
          :disabled="form.processing"
        >
          <span v-if="form.processing">Сохранение...</span>
          <span v-else>Сохранить</span>
        </button>
        
        <button
          v-if="release"
          type="button"
          @click="deleteRelease"
          class="btn btn-danger"
          :disabled="form.processing"
        >
          Удалить
        </button>
        
        <span v-if="form.isDirty" class="text-sm text-amber-600">
          Несохранённые изменения
        </span>
        
        <span v-if="form.recentlySuccessful" class="text-sm text-green-600">
          Сохранено!
        </span>
      </div>
    </div>
  </form>
</template>
```

### Паттерны тестирования

**Принципы тестирования:**
- Никаких хрупких тестов — тестируй только публичные API и возвращаемые значения
- Без утечки доменных знаний — тесты не должны знать о внутренней реализации
- Тестируй только публичные методы
- Используй только **Pest PHP** как фреймворк тестирования
- Arrange-Act-Assert (AAA) паттерн

**Структура теста:**
```php
// tests/Feature/ReleaseManagementTest.php
use App\Models\Project;
use App\Models\Release;
use App\Models\User;

beforeEach(function () {
    // Setup выполняется перед каждым тестом
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

test('пользователь может создать релиз', function () {
    // Arrange (подготовка)
    $project = Project::factory()->create();
    $this->user->givePermissionTo('create-releases');
    
    // Act (действие)
    $response = $this->post('/releases', [
        'name' => 'Version 1.0',
        'version' => '1.0.0',
        'projectId' => $project->id,
        'releaseDate' => now()->addWeek()->toDateString(),
    ]);
    
    // Assert (проверки)
    $response->assertRedirect();
    expect(Release::count())->toBe(1);
    
    $release = Release::first();
    expect($release->name)->toBe('Version 1.0');
    expect($release->version)->toBe('1.0.0');
});

test('нельзя создать релиз без разрешения', function () {
    $project = Project::factory()->create();
    
    $response = $this->post('/releases', [
        'name' => 'Version 1.0',
        'version' => '1.0.0',
        'projectId' => $project->id,
    ]);
    
    $response->assertForbidden();
    expect(Release::count())->toBe(0);
});

test('версия релиза должна быть уникальной', function () {
    $this->user->givePermissionTo('create-releases');
    $project = Project::factory()->create();
    Release::factory()->create(['version' => '1.0.0']);
    
    $response = $this->post('/releases', [
        'name' => 'Version 1.0',
        'version' => '1.0.0',
        'projectId' => $project->id,
    ]);
    
    $response->assertSessionHasErrors('version');
});

it('может обновить релиз', function () {
    $this->user->givePermissionTo('edit-releases');
    $release = Release::factory()->create([
        'name' => 'Old Name',
    ]);
    
    $response = $this->put("/releases/{$release->id}", [
        'name' => 'New Name',
        'version' => $release->version,
    ]);
    
    $response->assertRedirect();
    expect($release->fresh()->name)->toBe('New Name');
});
```

**Тестирование с моками:**
```php
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Notification;
use App\Events\ReleaseCreated;
use App\Notifications\NewReleaseNotification;

test('создание релиза отправляет уведомления', function () {
    Notification::fake();
    Event::fake([ReleaseCreated::class]);
    
    $this->user->givePermissionTo('create-releases');
    $project = Project::factory()->create();
    
    $this->post('/releases', [
        'name' => 'Version 1.0',
        'version' => '1.0.0',
        'projectId' => $project->id,
    ]);
    
    Event::assertDispatched(ReleaseCreated::class);
});
```

**Dataset для параметризованных тестов:**
```php
// tests/Datasets/Versions.php
dataset('valid_versions', [
    '1.0.0',
    '2.5.3',
    '10.20.30',
]);

dataset('invalid_versions', [
    '1.0',      // не хватает патча
    'v1.0.0',   // префикс
    '1.0.0-beta', // суффикс
    'latest',   // не число
]);

// Использование
test('валидные версии принимаются', function (string $version) {
    // тест
})->with('valid_versions');

test('невалидные версии отклоняются', function (string $version) {
    // тест
})->with('invalid_versions');
```

## Продвинутые практики Frontend

### Tailwind CSS — стилизация

**Основные принципы:**
- Используй utility-first подход
- Не создавай отдельные CSS файлы для компонентов
- Используй `@apply` только для повторяющихся паттернов
- Настраивай тему в `tailwind.config.js`

**Utility-first подход:**
```vue
<template>
  <!-- ✅ Хорошо: utility классы -->
  <div class="flex items-center justify-between p-4 bg-white rounded-lg shadow-md">
    <h3 class="text-xl font-bold text-gray-900">{{ title }}</h3>
    <button class="px-4 py-2 text-white bg-blue-600 rounded hover:bg-blue-700 transition">
      Действие
    </button>
  </div>
  
  <!-- ❌ Плохо: кастомные классы без необходимости -->
  <div class="custom-card">
    <h3 class="custom-title">{{ title }}</h3>
    <button class="custom-button">Действие</button>
  </div>
</template>

<style scoped>
/* ❌ Избегай */
.custom-card {
  display: flex;
  padding: 1rem;
  background: white;
}
</style>
```

**Переиспользуемые стили через @apply:**
```css
/* resources/css/app.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer components {
  /* Только для часто повторяющихся паттернов */
  .btn {
    @apply px-4 py-2 rounded font-medium transition duration-200;
  }
  
  .btn-primary {
    @apply btn bg-blue-600 text-white hover:bg-blue-700;
  }
  
  .btn-secondary {
    @apply btn bg-gray-200 text-gray-800 hover:bg-gray-300;
  }
  
  .btn-danger {
    @apply btn bg-red-600 text-white hover:bg-red-700;
  }
  
  .card {
    @apply bg-white rounded-lg shadow-md p-6;
  }
  
  .input {
    @apply w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-2 focus:ring-blue-500 focus:border-transparent;
  }
}
```

**Настройка темы:**
```javascript
// tailwind.config.js
export default {
  content: [
    './resources/**/*.blade.php',
    './resources/**/*.js',
    './resources/**/*.vue',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          900: '#1e3a8a',
        },
        secondary: {
          // кастомные цвета
        },
      },
      fontFamily: {
        sans: ['Inter var', 'sans-serif'],
      },
      spacing: {
        '72': '18rem',
        '84': '21rem',
        '96': '24rem',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
  ],
}
```

**Адаптивный дизайн:**
```vue
<template>
  <div class="
    grid 
    grid-cols-1       /* мобильные: 1 колонка */
    md:grid-cols-2    /* планшеты: 2 колонки */
    lg:grid-cols-3    /* десктоп: 3 колонки */
    xl:grid-cols-4    /* большие экраны: 4 колонки */
    gap-4 
    p-4
  ">
    <div 
      v-for="release in releases" 
      :key="release.id"
      class="
        p-4 
        bg-white 
        rounded-lg 
        shadow
        hover:shadow-lg
        transition-shadow
        duration-200
      "
    >
      <h3 class="text-lg md:text-xl font-bold">{{ release.name }}</h3>
      <p class="text-sm md:text-base text-gray-600">{{ release.description }}</p>
    </div>
  </div>
</template>
```

**Dark mode (если нужен):**
```vue
<template>
  <div class="bg-white dark:bg-gray-800 text-gray-900 dark:text-white">
    <h1 class="text-2xl font-bold">{{ title }}</h1>
  </div>
</template>
```

### Условный рендеринг и списки

**v-if vs v-show:**
```vue
<template>
  <!-- v-if: полностью удаляет элемент из DOM -->
  <div v-if="isVisible">
    Этот блок рендерится только когда isVisible = true
  </div>
  
  <!-- v-show: скрывает через display: none -->
  <div v-show="isVisible">
    Этот блок всегда в DOM, но скрыт когда isVisible = false
  </div>
  
  <!-- ✅ Используй v-if для редких переключений -->
  <ExpensiveComponent v-if="shouldRender" />
  
  <!-- ✅ Используй v-show для частых переключений -->
  <div v-show="isExpanded">
    Контент, который часто показывается/скрывается
  </div>
</template>
```

**v-for с :key:**
```vue
<template>
  <!-- ✅ Всегда используй уникальный :key -->
  <div 
    v-for="release in releases" 
    :key="release.id"
    class="release-card"
  >
    {{ release.name }}
  </div>
  
  <!-- ❌ Плохо: использование индекса как key -->
  <div 
    v-for="(release, index) in releases" 
    :key="index"
  >
    {{ release.name }}
  </div>
  
  <!-- v-for с v-if (избегай) -->
  <!-- ❌ Плохо -->
  <div 
    v-for="release in releases" 
    :key="release.id"
    v-if="release.isPublished"
  >
    {{ release.name }}
  </div>
  
  <!-- ✅ Хорошо: фильтруй в computed -->
  <div 
    v-for="release in publishedReleases" 
    :key="release.id"
  >
    {{ release.name }}
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  releases: Array,
})

const publishedReleases = computed(() => {
  return props.releases.filter(r => r.isPublished)
})
</script>
```

### Производительность и оптимизация

**Lazy loading компонентов:**
```javascript
// resources/js/app.js
import { defineAsyncComponent } from 'vue'

// Обычный импорт (загружается сразу)
import ReleaseCard from './Components/Release/ReleaseCard.vue'

// Ленивый импорт (загружается при использовании)
const ReleaseList = defineAsyncComponent(() => 
  import('./Components/Release/ReleaseList.vue')
)

const HeavyChart = defineAsyncComponent(() => 
  import('./Components/Charts/HeavyChart.vue')
)
```

**Используй в компонентах:**
```vue
<script setup>
import { defineAsyncComponent } from 'vue'

// Ленивая загрузка тяжёлых компонентов
const Chart = defineAsyncComponent(() => 
  import('@/Components/Charts/Chart.vue')
)
</script>

<template>
  <div>
    <Suspense>
      <template #default>
        <Chart :data="chartData" />
      </template>
      <template #fallback>
        <div class="loading">Загрузка графика...</div>
      </template>
    </Suspense>
  </div>
</template>
```

**Мемоизация с computed:**
```vue
<script setup>
import { ref, computed } from 'vue'

const releases = ref([/* много данных */])

// ❌ Плохо: вычисление на каждый рендер
const filteredReleases = releases.value.filter(r => r.status === 'published')

// ✅ Хорошо: кэшируется через computed
const publishedReleases = computed(() => {
  return releases.value.filter(r => r.status === 'published')
})

// Сложное вычисление с зависимостями
const statistics = computed(() => {
  const total = releases.value.length
  const published = publishedReleases.value.length
  const draft = total - published
  
  return {
    total,
    published,
    draft,
    publishedPercentage: total > 0 ? (published / total) * 100 : 0,
  }
})
</script>
```

**Виртуальная прокрутка для длинных списков:**
```vue
<script setup>
import { ref, computed } from 'vue'

const releases = ref([/* тысячи элементов */])
const visibleRange = ref({ start: 0, end: 20 })
const itemHeight = 100 // высота одного элемента в px

const visibleReleases = computed(() => {
  return releases.value.slice(visibleRange.value.start, visibleRange.value.end)
})

const handleScroll = (event) => {
  const scrollTop = event.target.scrollTop
  const start = Math.floor(scrollTop / itemHeight)
  const end = start + 20
  
  visibleRange.value = { start, end }
}
</script>

<template>
  <div 
    class="list-container" 
    @scroll="handleScroll"
    :style="{ height: `${releases.length * itemHeight}px` }"
  >
    <div 
      v-for="release in visibleReleases" 
      :key="release.id"
      :style="{ height: `${itemHeight}px` }"
    >
      {{ release.name }}
    </div>
  </div>
</template>
```

### Доступность (Accessibility)

**Семантический HTML:**
```vue
<template>
  <!-- ✅ Хорошо: семантические теги -->
  <header class="header">
    <nav aria-label="Главное меню">
      <ul>
        <li><a href="/releases">Релизы</a></li>
        <li><a href="/projects">Проекты</a></li>
      </ul>
    </nav>
  </header>
  
  <main>
    <article>
      <h1>{{ release.name }}</h1>
      <p>{{ release.description }}</p>
    </article>
  </main>
  
  <!-- ❌ Плохо: div soup -->
  <div class="header">
    <div class="nav">
      <div class="nav-item">
        <div class="link">Релизы</div>
      </div>
    </div>
  </div>
</template>
```

**ARIA атрибуты:**
```vue
<template>
  <button
    @click="toggleMenu"
    aria-expanded="isMenuOpen"
    aria-controls="menu"
    aria-label="Открыть меню"
  >
    <span aria-hidden="true">☰</span>
  </button>
  
  <div
    id="menu"
    role="menu"
    :aria-hidden="!isMenuOpen"
  >
    <!-- меню -->
  </div>
  
  <!-- Модальное окно -->
  <div
    v-if="isModalOpen"
    role="dialog"
    aria-modal="true"
    aria-labelledby="modal-title"
  >
    <h2 id="modal-title">Заголовок модального окна</h2>
    <!-- контент -->
  </div>
</template>
```

**Клавиатурная навигация:**
```vue
<script setup>
const handleKeydown = (event) => {
  if (event.key === 'Escape') {
    closeModal()
  }
  
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    handleAction()
  }
}
</script>

<template>
  <div
    tabindex="0"
    @keydown="handleKeydown"
    @click="handleAction"
    role="button"
  >
    Кликабельный элемент
  </div>
</template>
```

## Настройка окружения

### Первоначальная настройка

Скопируйте `.env.example` в `.env`:
```bash
cp .env.example .env
sail up -d
sail php artisan key:generate
sail php artisan migrate --seed
sail npm install
sail npm run build
```

### Ключевые переменные окружения

```env
# Приложение
APP_NAME="Release Manager"
APP_ENV=local          # local, staging, production
APP_DEBUG=true         # false в production
APP_URL=http://localhost

# База данных (PostgreSQL)
DB_CONNECTION=pgsql
DB_HOST=pgsql
DB_PORT=5432
DB_DATABASE=release_manager
DB_USERNAME=sail
DB_PASSWORD=password

# Redis (для очередей и кэша)
QUEUE_CONNECTION=redis # sync для тестирования
CACHE_DRIVER=redis     # array для тестирования
REDIS_HOST=redis
REDIS_PORT=6379

# Почта (для уведомлений)
MAIL_MAILER=smtp
MAIL_HOST=mailpit  # для локальной разработки
MAIL_PORT=1025

# Очереди
QUEUE_CONNECTION=redis # sync в тестах, redis в production
```

### Окружения

**Local (разработка):**
- `APP_ENV=local`
- `APP_DEBUG=true`
- `QUEUE_CONNECTION=sync` или `redis`
- Используй Mailpit для локальных email

**Testing:**
- `APP_ENV=testing`
- `DB_CONNECTION=sqlite` (в памяти)
- `QUEUE_CONNECTION=sync`
- Все внешние сервисы мокаются

**Production:**
- `APP_ENV=production`
- `APP_DEBUG=false`
- `QUEUE_CONNECTION=redis`
- Все секреты в переменных окружения

## Часто используемые команды

### Artisan команды

| Команда | Назначение |
|---------|-----------|
| `sail up -d` | Запустить Docker контейнеры в фоне |
| `sail down` | Остановить Docker контейнеры |
| `sail artisan test` | Запустить все тесты |
| `sail artisan test --filter="название теста"` | Запустить конкретный тест |
| `sail artisan migrate` | Запустить миграции |
| `sail artisan migrate:fresh --seed` | Пересоздать БД с сидами |
| `sail artisan db:seed` | Запустить сиды |
| `sail artisan tinker` | Интерактивная PHP оболочка |
| `sail artisan queue:work` | Запустить обработчик очередей |
| `sail artisan queue:listen` | Запустить обработчик с автоперезапуском |
| `sail artisan optimize` | Оптимизировать приложение (кэш конфигов) |
| `sail artisan optimize:clear` | Очистить все кэши |
| `sail artisan permission:cache-reset` | Сбросить кэш разрешений Spatie |
| `sail artisan l5-swagger:generate` | Сгенерировать Swagger документацию API |

### Генераторы кода

| Команда | Назначение |
|---------|-----------|
| `sail artisan make:model Release -mfc` | Создать модель + миграция + фабрика + контроллер |
| `sail artisan make:controller ReleaseController` | Создать контроллер |
| `sail artisan make:request CreateReleaseRequest` | Создать Form Request |
| `sail artisan make:action CreateReleaseAction` | Создать Action (если есть кастомная команда) |
| `sail artisan make:event ReleaseCreated` | Создать Event |
| `sail artisan make:listener SendNotificationListener` | Создать Listener |
| `sail artisan make:exception ReleaseException` | Создать Exception |
| `sail artisan make:test ReleaseTest` | Создать Pest тест |
| `sail artisan make:migration create_releases_table` | Создать миграцию |
| `sail artisan make:seeder ReleaseSeeder` | Создать Seeder |

### NPM команды

| Команда | Назначение |
|---------|-----------|
| `sail npm install` | Установить зависимости |
| `sail npm run dev` | Запустить Vite dev сервер |
| `sail npm run build` | Собрать для production |
| `sail npm run build -- --watch` | Пересборка при изменениях |

### Линтинг и форматирование

| Команда | Назначение |
|---------|-----------|
| `sail vendor/bin/pint` | Форматировать PHP код |
| `sail vendor/bin/pint --test` | Проверить стиль без изменений |
| `sail vendor/bin/pint app/Actions` | Форматировать конкретную директорию |

## Git Workflow

### Правила работы с Git

- **Понятные коммиты:** Используй [Conventional Commits](https://www.conventionalcommits.org/)
- **Pre-commit хуки:** Убедись, что хук установлен и отрабатывает корректно
- **Небольшие коммиты:** Один коммит = одна логическая единица изменений
- **Ветки:** Именование `feature/название`, `fix/название`, `release/версия`
- **Согласование:** Все взаимодействия с Git только через моё подтверждение

### Conventional Commits

```bash
# Типы коммитов:
feat: новая функциональность
fix: исправление бага
docs: изменения в документации
style: форматирование кода
refactor: рефакторинг без изменения функциональности
test: добавление/изменение тестов
chore: изменения в сборке, зависимостях

# Примеры:
feat(releases): добавить фильтрацию по статусу
fix(auth): исправить редирект после логина
docs(readme): обновить инструкции по установке
refactor(actions): упростить CreateReleaseAction
test(releases): добавить тесты для публикации релиза
```

### Структура веток

```
main (production)
  ↑
develop (staging)
  ↑
feature/add-release-filters
feature/improve-dashboard
fix/release-date-validation
```

### Pre-commit хук

`.githooks/pre-commit`:
```bash
#!/bin/bash

echo "Running pre-commit checks..."

# Форматирование PHP
./vendor/bin/pint --test
if [ $? -ne 0 ]; then
    echo "❌ Pint checks failed. Run './vendor/bin/pint' to fix."
    exit 1
fi

# Запуск тестов (только изменённые файлы)
php artisan test --parallel
if [ $? -ne 0 ]; then
    echo "❌ Tests failed."
    exit 1
fi

echo "✅ Pre-commit checks passed!"
exit 0
```

## Антипаттерны и частые ошибки

### Backend

**❌ Бизнес-логика в контроллерах:**
```php
// Плохо
public function store(Request $request) {
    $release = Release::create($request->all());
    
    if (Release::where('version', $release->version)->count() > 1) {
        // сложная логика в контроллере
    }
    
    // отправка уведомлений в контроллере
    Mail::to($users)->send(new ReleaseCreated($release));
}

// Хорошо
public function store(CreateReleaseRequest $request) {
    $action = app(CreateReleaseAction::class);
    $release = $action->handle($request->toDto());
    
    return redirect()->route('releases.show', $release);
}
```

**❌ try/catch в контроллерах:**
```php
// Плохо
public function store(Request $request) {
    try {
        $release = Release::create($request->all());
    } catch (\Exception $e) {
        return back()->withErrors(['error' => 'Ошибка']);
    }
}

// Хорошо: выбрасывай кастомные исключения
public function store(CreateReleaseRequest $request) {
    $action = app(CreateReleaseAction::class);
    $release = $action->handle($request->toDto()); // исключение обработается автоматически
    
    return redirect()->route('releases.show', $release);
}
```

**❌ N+1 проблема:**
```php
// Плохо
$projects = Project::all();
foreach ($projects as $project) {
    echo $project->releases->count(); // запрос на каждой итерации
}

// Хорошо
$projects = Project::withCount('releases')->get();
foreach ($projects as $project) {
    echo $project->releases_count; // один запрос
}
```

**❌ Массовые операции в цикле:**
```php
// Плохо
foreach ($releases as $release) {
    $release->update(['status' => 'published']); // N запросов
}

// Хорошо
Release::whereIn('id', $releaseIds)->update(['status' => 'published']); // 1 запрос
```

### Frontend

**❌ Прямое изменение props:**
```vue
<script setup>
const props = defineProps({ count: Number })

// Плохо
const increment = () => {
  props.count++ // нельзя изменять props
}

// Хорошо
const emit = defineEmits(['update:count'])
const increment = () => {
  emit('update:count', props.count + 1)
}
</script>
```

**❌ Не используй ref() для объектов/массивов:**
```javascript
// Плохо
const user = ref({ name: 'John', age: 30 })
user.value.name = 'Jane' // потеря реактивности при деструктуризации

// Хорошо
const user = reactive({ name: 'John', age: 30 })
user.name = 'Jane' // реактивность сохраняется
```

**❌ Мутации в computed:**
```javascript
// Плохо
const sortedItems = computed(() => {
  return props.items.sort() // мутирует исходный массив!
})

// Хорошо
const sortedItems = computed(() => {
  return [...props.items].sort() // копия массива
})
```

**❌ Тяжёлые вычисления без мемоизации:**
```vue
<script setup>
// Плохо: вычисляется на каждый рендер
const filteredReleases = props.releases.filter(r => r.status === 'published')

// Хорошо: кэшируется
const filteredReleases = computed(() => {
  return props.releases.filter(r => r.status === 'published')
})
</script>
```

## Производительность и оптимизация

### Backend

**Индексы в БД:**
```php
// Всегда добавляй индексы для полей, по которым фильтруешь
Schema::create('releases', function (Blueprint $table) {
    $table->id();
    $table->foreignId('project_id')->constrained()->index(); // внешний ключ с индексом
    $table->string('version')->unique(); // уникальный индекс
    $table->enum('status', [...])->index(); // индекс для фильтрации
    $table->timestamp('release_date')->index(); // индекс для сортировки
    
    // Составной индекс для частых запросов
    $table->index(['status', 'release_date']);
});
```

**Eager Loading:**
```php
// Плохо: N+1
$releases = Release::all();
foreach ($releases as $release) {
    echo $release->project->name; // N запросов
}

// Хорошо: 2 запроса
$releases = Release::with('project')->get();
foreach ($releases as $release) {
    echo $release->project->name;
}

// Вложенные отношения
$releases = Release::with('project.team.members')->get();

// Подсчёт связанных записей
$releases = Release::withCount('features')->get();
```

**Кэширование:**
```php
// Кэш запросов
$releases = Cache::remember('releases.published', 3600, function () {
    return Release::published()->with('project')->get();
});

// Инвалидация кэша
Cache::forget('releases.published');

// Тегированный кэш
Cache::tags(['releases'])->put('list', $releases, 3600);
Cache::tags(['releases'])->flush(); // очистить все с тегом
```

### Frontend

**Виртуализация списков:**
- Используй виртуальную прокрутку для списков > 100 элементов
- Рендери только видимые элементы

**Ленивая загрузка изображений:**
```vue
<template>
  <img 
    :src="release.imageUrl" 
    loading="lazy"
    alt="Release image"
  />
</template>
```

**Debounce для поиска:**
```vue
<script setup>
import { ref, watch } from 'vue'
import { debounce } from 'lodash-es'

const searchQuery = ref('')
const results = ref([])

const searchReleases = debounce(async (query) => {
  const response = await fetch(`/api/releases/search?q=${query}`)
  results.value = await response.json()
}, 300)

watch(searchQuery, (newQuery) => {
  searchReleases(newQuery)
})
</script>
```

## Безопасность

### CSRF Protection
- Всегда включён для POST/PUT/DELETE запросов
- Inertia автоматически добавляет CSRF токен

### XSS Protection
```vue
<!-- ✅ Безопасно: автоматическое экранирование -->
<div>{{ release.name }}</div>

<!-- ❌ Опасно: отключение экранирования -->
<div v-html="release.description"></div>

<!-- ✅ Безопасно: sanitize перед выводом -->
<div v-html="sanitizeHtml(release.description)"></div>
```

### SQL Injection
```php
// ✅ Безопасно: параметризованные запросы
DB::select('SELECT * FROM releases WHERE status = ?', [$status]);

// ✅ Безопасно: Query Builder
Release::where('status', $status)->get();

// ❌ Опасно: конкатенация строк
DB::select("SELECT * FROM releases WHERE status = '{$status}'");
```

### Mass Assignment
```php
// ✅ Используй $fillable или $guarded
class Release extends Model {
    protected $fillable = ['name', 'version', 'description'];
    // или
    protected $guarded = ['id', 'created_at', 'updated_at'];
}

// ✅ Используй validated() в контроллерах
$release = Release::create($request->validated());
```

## Полезные ссылки на документацию

- [Laravel 12 Docs](https://laravel.com/docs/12.x)
- [Inertia.js](https://inertiajs.com/)
- [Pest Testing](https://pestphp.com/)
- [Vue 3 Guide](https://vuejs.org/)
- [Tailwind CSS](https://tailwindcss.com/)
- [Spatie Laravel Data](https://spatie.be/docs/laravel-data)
- [Spatie Laravel Permission](https://spatie.be/docs/laravel-permission)
- [darkaonline/l5-swagger](https://github.com/DarkaOnLine/L5-Swagger) — **API документация (стандарт)**
- [OpenAPI 3.0 Specification](https://swagger.io/specification/)
- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [Redis Documentation](https://redis.io/docs/)

## Дополнительные рекомендации

### Логирование

```php
// Используй фасад Log с контекстом
Log::info('Release created', [
    'release_id' => $release->id,
    'user_id' => auth()->id(),
]);

Log::error('Failed to publish release', [
    'release_id' => $release->id,
    'error' => $e->getMessage(),
    'trace' => $e->getTraceAsString(),
]);

// Каналы логирования (config/logging.php)
Log::channel('slack')->critical('Production error');
```

### Мониторинг и отладка

**Laravel Telescope (development):**
```bash
sail artisan telescope:install
sail artisan migrate
```

**Laravel Pail (real-time logs):**
```bash
sail artisan pail --filter=error
```

### Очереди

**Создание Job:**
```php
namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessReleaseNotifications implements ShouldQueue
{
    use Queueable, InteractsWithQueue, SerializesModels;
    
    public $tries = 3;
    public $timeout = 120;
    
    public function __construct(public Release $release) {}
    
    public function handle(): void
    {
        // Отправка уведомлений
    }
    
    public function failed(\Throwable $exception): void
    {
        // Обработка ошибки
        Log::error('Job failed', [
            'job' => self::class,
            'release_id' => $this->release->id,
            'error' => $exception->getMessage(),
        ]);
    }
}

// Диспатч Job
ProcessReleaseNotifications::dispatch($release);
ProcessReleaseNotifications::dispatch($release)->delay(now()->addMinutes(5));
```

---

**Помни:** Этот документ — живой. Обновляй его при изменении соглашений или добавлении новых паттернов.
