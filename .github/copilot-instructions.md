# Инструкции для Copilot

## Быстрая настройка

```bash
sail up -d && sail php artisan key:generate --force && sail php artisan optimize && sail php artisan migrate --seed && sail npm run build
```

## Правила работы

- **Двойное затруднение:** спотыкаешься >2 раз — спрашивай
- **Сохранность данных:** не удалять файлы без разрешения
- **Контроль версий:** коммит только с разрешения пользователя
- **Хирургическая точность:** не переписывай файл целиком ради пары строк
- **Явное лучше неявного:** избегай магии Laravel, предпочитай явное DI
- По каждой фиче — спецификация в `specifications/`
- Каждый API эндпоинт документируй в Swagger

## Стек технологий

| Слой | Технология |
|---|---|
| Backend | Laravel 12 + Inertia.js |
| Frontend | Vue 3 (Composition API) + **shadcn-vue** + Tailwind CSS |
| БД | PostgreSQL (prod) / SQLite (tests) |
| Авторизация | **Spatie Laravel Permission** (СТАНДАРТ) |
| API Auth | Laravel Sanctum |
| DTO | **Spatie Laravel Data** (СТАНДАРТ) |
| API Docs | **darkaonline/l5-swagger** (СТАНДАРТ) |
| Тесты | **Pest PHP** |
| Сборка | Vite |
| Контейнеры | Laravel Sail (Docker) |
| Очереди | Redis (prod) / sync (tests) |

## Архитектура

**Event-Driven + Clean Architecture:**
```
Request → FormRequest (валидация) → Controller → Action → Model
                ↓DTO                                    ↓
           Events/Jobs → Listeners              Response (Inertia/JSON)
```

### Структура директорий

```
app/
├── Actions/          # бизнес-логика, handle(DTO): Model
├── Data/             # Spatie Data DTOs
├── Events/ + Listeners/
├── Exceptions/       # implements Responsable
├── Http/
│   ├── Controllers/  # тонкий слой
│   └── Requests/     # валидация + toDto()
└── Models/           # только данные

resources/js/
├── components/ui/    # shadcn-vue (авто-генерируются CLI)
├── Components/       # бизнес-компоненты (Release/, Shared/)
├── Composables/      # usePermissions, useDateFormat
├── Layouts/          # AppLayout (+ <Toaster/>), AuthLayout
├── Pages/            # Inertia страницы
└── Utils/
```

## Авторизация — Spatie Permission (СТАНДАРТ)

```php
// Middleware на роутах
Route::post('/releases', [...])->middleware('permission:create-releases');
Route::group(['middleware' => ['role:admin']], fn() => ...);

// Проверки в коде
$user->hasPermissionTo('edit-releases');
$user->hasRole('admin');
$user->hasAnyRole(['admin', 'release-manager']);
$user->assignRole('release-manager');
$user->givePermissionTo('edit-releases');

// Inertia props
return Inertia::render('Releases/Index', [
    'canCreate' => auth()->user()->can('create-releases'),
    'isAdmin'   => auth()->user()->hasRole('admin'),
]);
```

Сброс кэша: `sail artisan permission:cache-reset`

## DTO — Spatie Laravel Data (СТАНДАРТ)

- Все данные между слоями — через DTO, immutable, camelCase свойства
- `#[MapInputName(SnakeCaseMapper::class)]` для авто-маппинга snake_case → camelCase
- Валидация — в FormRequest, DTO только для типизации

```php
#[MapInputName(SnakeCaseMapper::class)]
class ReleaseData extends Data
{
    public function __construct(
        public string $name,
        public string $version,
        public ?Carbon $releaseDate,
        public ProjectData $project,     // вложенный DTO
        public string|Optional $description, // Optional для PATCH
    ) {}
}

// Создание
$dto = ReleaseData::from($request->validated());
$dto = ReleaseData::from($model);
$model->update($dto->only('name', 'version')->toArray());
```

## Backend паттерны

### Controller (тонкий слой)

```php
class ReleaseController extends Controller
{
    public function __construct()
    {
        $this->middleware('permission:create-releases')->only(['create', 'store']);
        $this->middleware('permission:edit-releases')->only(['edit', 'update']);
    }

    public function store(CreateReleaseRequest $request): RedirectResponse
    {
        $release = app(CreateReleaseAction::class)->handle($request->toDto());
        return redirect()->route('releases.show', $release->id);
    }
}
```

### Action (вся бизнес-логика)

```php
class CreateReleaseAction
{
    public function handle(CreateReleaseData $data): Release
    {
        if (Release::where('version', $data->version)->exists()) {
            throw ReleaseException::versionAlreadyExists($data->version);
        }

        return DB::transaction(function () use ($data) {
            $release = Release::create([...]);
            event(new ReleaseCreated($release));
            return $release->fresh();
        });
    }
}
```

### FormRequest

```php
class CreateReleaseRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create-releases');
    }

    public function rules(): array
    {
        return [
            'name'        => ['required', 'string', 'max:255'],
            'version'     => ['required', 'regex:/^\d+\.\d+\.\d+$/', Rule::unique('releases')],
            'projectId'   => ['required', Rule::exists('projects', 'id')],
            'releaseDate' => ['required', 'date', 'after:today'],
        ];
    }

    public function toDto(): CreateReleaseData
    {
        return CreateReleaseData::from($this->validated());
    }
}
```

### Exceptions

- Одно исключение на сущность, фабричные методы, реализует `Responsable`
- Числовые коды: `1xxx` — auth, `2xxx` — releases, `3xxx` — projects, `4xxx` — права

```php
class ReleaseException extends \Exception implements Responsable
{
    private function __construct(
        string $message,
        private int $errorCode,
        private string $userMessage,
        int $statusCode,
        private bool $shouldReport = false,
    ) { parent::__construct($message, $statusCode); }

    public static function notFound(int $id): self
    {
        return new self("Release {$id} not found", 2001, 'Релиз не найден', 404);
    }

    public static function versionAlreadyExists(string $v): self
    {
        return new self("Version {$v} exists", 2003, 'Версия уже существует', 409);
    }

    public function toResponse($request): JsonResponse|RedirectResponse
    {
        if ($request->expectsJson()) {
            return response()->json([
                'success' => false,
                'error'   => ['code' => $this->errorCode, 'message' => $this->userMessage],
            ], $this->getCode());
        }
        return redirect()->back()->withErrors(['error' => $this->userMessage]);
    }
}
// Никогда try/catch в контроллерах!
```

### Models (только данные)

```php
class Release extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = ['name', 'version', 'description', 'project_id', 'status', 'release_date'];
    protected $casts = ['release_date' => 'datetime', 'status' => ReleaseStatus::class];

    public function project(): BelongsTo { return $this->belongsTo(Project::class); }

    public function scopePublished($query) { return $query->where('status', ReleaseStatus::Published); }
}
```

### База данных

- Простые запросы → Eloquent с eager loading (`with()`, `withCount()`)
- Сложные → Query Builder или нативный SQL (`DB::select('...', [$param])`)
- Bulk update: `Release::whereIn('id', $ids)->update([...])` — не цикл
- Индексы на полях фильтрации/сортировки, составные для частых запросов

```php
Schema::create('releases', function (Blueprint $table) {
    $table->id();
    $table->foreignId('project_id')->constrained()->cascadeOnDelete();
    $table->string('version')->unique();
    $table->enum('status', ['draft', 'published', 'archived'])->default('draft');
    $table->timestamp('release_date')->nullable();
    $table->timestamps();
    $table->softDeletes();
    $table->index(['status', 'release_date']);
});
```

### Events / Listeners

```php
class ReleaseCreated
{
    use Dispatchable, SerializesModels;
    public function __construct(public Release $release) {}
}

class SendReleaseNotificationListener implements ShouldQueue
{
    public function handle(ReleaseCreated $event): void
    {
        $event->release->project->subscribers->each(
            fn($u) => $u->notify(new NewReleaseNotification($event->release))
        );
    }
}
```

## API документация — Swagger (СТАНДАРТ)

```bash
sail composer require darkaonline/l5-swagger
sail artisan vendor:publish --provider "L5Swagger\L5SwaggerServiceProvider"
sail artisan l5-swagger:generate
```

`.env`: `L5_SWAGGER_GENERATE_ALWAYS=true`  
Просмотр: `http://localhost/api/documentation`  
Схемы: `app/Http/Controllers/Api/Schemas/`

**Правила:** документировать все публичные эндпоинты, все параметры, все ответы (200/201/401/403/404/422/500), использовать `security={{"bearerAuth":{}}}`, добавлять `example=...`, версионировать API (`/api/v1/`).

```php
// Базовый контроллер
/**
 * @OA\Info(version="1.0.0", title="Release Manager API")
 * @OA\Server(url="/api")
 * @OA\SecurityScheme(securityScheme="bearerAuth", type="http", scheme="bearer")
 */
abstract class Controller {}

// Эндпоинт
/**
 * @OA\Post(
 *     path="/v1/releases",
 *     tags={"Releases"},
 *     security={{"bearerAuth":{}}},
 *     @OA\RequestBody(required=true, @OA\JsonContent(ref="#/components/schemas/CreateReleaseRequest")),
 *     @OA\Response(response=201, description="Релиз создан", @OA\JsonContent(
 *         @OA\Property(property="success", type="boolean", example=true),
 *         @OA\Property(property="data", ref="#/components/schemas/Release")
 *     )),
 *     @OA\Response(response=422, description="Ошибка валидации", @OA\JsonContent(ref="#/components/schemas/ValidationErrorResponse")),
 *     @OA\Response(response=403, description="Нет прав", @OA\JsonContent(ref="#/components/schemas/ErrorResponse"))
 * )
 */
public function store(CreateReleaseRequest $request): JsonResponse
{
    $release = app(CreateReleaseAction::class)->handle($request->toDto());
    return response()->json(['success' => true, 'data' => $release], 201);
}

// Схема
/**
 * @OA\Schema(schema="Release", required={"id","name","version","status"},
 *     @OA\Property(property="id", type="integer", example=1),
 *     @OA\Property(property="name", type="string", example="Release v1.0.0"),
 *     @OA\Property(property="version", type="string", example="1.0.0"),
 *     @OA\Property(property="status", type="string", enum={"draft","ready","deployed","rolled_back"})
 * )
 * @OA\Schema(schema="ErrorResponse",
 *     @OA\Property(property="success", type="boolean", example=false),
 *     @OA\Property(property="error", type="object",
 *         @OA\Property(property="code", type="integer"),
 *         @OA\Property(property="message", type="string")
 *     )
 * )
 */
class ReleaseSchemas {}
```

## Frontend — shadcn-vue (СТАНДАРТ)

```bash
npx shadcn-vue@latest init
npx shadcn-vue@latest add button input card dialog select textarea label badge sonner table dropdown-menu
```

**Импорт:** всегда из `@/components/ui/<component>`

```vue
import { Button }                     from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Input }                      from '@/components/ui/input'
import { Label }                      from '@/components/ui/label'
import { Badge }                      from '@/components/ui/badge'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'
```

**Button variants:** `default` | `secondary` | `destructive` | `outline` | `ghost` | `link`  
**Button sizes:** `sm` | `default` | `lg` | `icon`

**Тосты — только vue-sonner (не создавай useToast.js):**
```js
import { toast } from 'vue-sonner'
toast.success('Готово')
toast.error('Ошибка', { description: '...' })
toast('Удалено', { action: { label: 'Отменить', onClick: fn } })
// В AppLayout.vue: <Toaster rich-colors />
```

**Базовый компонент:**
```vue
<script setup>
import { computed } from 'vue'
import { Button }   from '@/components/ui/button'
import { Card, CardHeader, CardTitle, CardContent } from '@/components/ui/card'
import { Badge }    from '@/components/ui/badge'

const props = defineProps({ release: { type: Object, required: true }, canEdit: Boolean })
const emit  = defineEmits(['updated'])

const statusVariant = computed(() =>
  ({ published: 'default', draft: 'secondary', archived: 'outline' }[props.release.status] ?? 'secondary')
)
</script>

<template>
  <Card>
    <CardHeader class="flex flex-row items-center justify-between">
      <CardTitle>{{ release.name }} <Badge :variant="statusVariant">{{ release.status }}</Badge></CardTitle>
      <Button v-if="canEdit" size="sm" @click="emit('updated', release)">Редактировать</Button>
    </CardHeader>
    <CardContent>
      <p class="text-muted-foreground">{{ release.description }}</p>
    </CardContent>
  </Card>
</template>
```

### Формы (Inertia useForm + shadcn-vue)

```vue
<script setup>
import { useForm }   from '@inertiajs/vue3'
import { toast }     from 'vue-sonner'
import { Button }    from '@/components/ui/button'
import { Input }     from '@/components/ui/input'
import { Label }     from '@/components/ui/label'
import { Textarea }  from '@/components/ui/textarea'
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select'

const props = defineProps({ release: Object, projects: Array })

const form = useForm({
  name: props.release?.name ?? '',
  version: props.release?.version ?? '',
  projectId: props.release?.projectId ?? null,
  description: props.release?.description ?? '',
})

const submit = () => {
  props.release
    ? form.put(`/releases/${props.release.id}`, { onSuccess: () => { form.reset(); toast.success('Обновлено') } })
    : form.post('/releases', { onSuccess: () => toast.success('Создан') })
}
</script>

<template>
  <form @submit.prevent="submit" class="space-y-4">
    <div class="space-y-2">
      <Label for="name">Название</Label>
      <Input id="name" v-model="form.name" :class="{ 'border-destructive': form.errors.name }" />
      <p v-if="form.errors.name" class="text-sm text-destructive">{{ form.errors.name }}</p>
    </div>

    <div class="space-y-2">
      <Label>Проект</Label>
      <Select v-model="form.projectId">
        <SelectTrigger><SelectValue placeholder="Выберите проект" /></SelectTrigger>
        <SelectContent>
          <SelectItem v-for="p in projects" :key="p.id" :value="p.id">{{ p.name }}</SelectItem>
        </SelectContent>
      </Select>
      <p v-if="form.errors.projectId" class="text-sm text-destructive">{{ form.errors.projectId }}</p>
    </div>

    <div class="space-y-2">
      <Label for="description">Описание</Label>
      <Textarea id="description" v-model="form.description" :rows="4" />
    </div>

    <div class="flex items-center gap-4">
      <Button type="submit" :disabled="form.processing">
        <Loader2 v-if="form.processing" class="mr-2 h-4 w-4 animate-spin" />
        Сохранить
      </Button>
      <Button v-if="release" variant="destructive" type="button" @click="form.delete(`/releases/${release.id}`)">
        Удалить
      </Button>
      <span v-if="form.isDirty" class="text-sm text-amber-600">Несохранённые изменения</span>
    </div>
  </form>
</template>
```

### Tailwind + shadcn-vue

- shadcn-vue использует **CSS переменные** (`--background`, `--foreground`, `--primary`, `--destructive`, `--muted-foreground`, `--border`, `--radius`)
- Tailwind — только для **layout/spacing** (flex, grid, gap, p, m); UI элементы — shadcn-vue компоненты
- Семантические цвета: `text-foreground`, `text-muted-foreground`, `text-destructive`, `bg-muted`
- **Не добавляй** `primary`/`secondary` цвета в `tailwind.config.js` вручную
- `darkMode: ['class']` в конфиге, тёмная тема автоматически через CSS переменные

```javascript
// tailwind.config.js
export default {
  darkMode: ['class'],
  content: ['./resources/**/*.{blade.php,js,vue}'],
  theme: {
    extend: { fontFamily: { sans: ['Inter var', 'sans-serif'] } },
  },
  plugins: [require('@tailwindcss/typography')],
}
```

### Vue 3 — ключевые правила

- Всегда `<script setup>` + Composition API
- `computed()` для вычислений, никогда прямые вычисления в template
- `reactive()` для объектов, `ref()` для примитивов
- Никогда не мутировать props — `emit('update:x', value)`
- `v-for` всегда с уникальным `:key="item.id"` (не индекс)
- `v-if` отдельно от `v-for` — фильтруй в `computed`
- `debounce` для поиска (300ms), `defineAsyncComponent` для тяжёлых компонентов

### Composables

**usePermissions** — читает `page.props.auth.user`, методы: `can()`, `hasRole()`, `hasAnyRole()`

```js
export function usePermissions() {
  const page = usePage()
  const user = computed(() => page.props.auth?.user)
  const can     = (p) => user.value?.permissions?.includes(p) ?? false
  const hasRole = (r) => user.value?.roles?.includes(r) ?? false
  return { user, can, hasRole, hasAnyRole: (rs) => rs.some(hasRole) }
}
```

**useDateFormat** — `formatDate(date, 'short'|'long'|'time'|'full')`, `timeAgo()`, `isToday()`, `isFuture()` через `Intl.DateTimeFormat('ru-RU')`.

## Тестирование — Pest PHP

- AAA паттерн (Arrange / Act / Assert)
- Только публичные методы, без доменных знаний о реализации

```php
beforeEach(function () {
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

test('пользователь может создать релиз', function () {
    $this->user->givePermissionTo('create-releases');
    $project = Project::factory()->create();

    $response = $this->post('/releases', [
        'name' => 'v1.0', 'version' => '1.0.0',
        'projectId' => $project->id, 'releaseDate' => now()->addWeek()->toDateString(),
    ]);

    $response->assertRedirect();
    expect(Release::first()->version)->toBe('1.0.0');
});

// Моки
Event::fake([ReleaseCreated::class]);
Notification::fake();
Event::assertDispatched(ReleaseCreated::class);

// Datasets
dataset('valid_versions', ['1.0.0', '2.5.3', '10.20.30']);
test('версия валидна', fn(string $v) => /* ... */)->with('valid_versions');
```

## Команды

```bash
# Тесты
sail artisan test --testsuite=Unit|Feature --testdox
sail artisan test --filter="название" --coverage --min=80

# Линтинг
sail vendor/bin/pint [--test] [app/Actions]

# Миграции / БД
sail artisan migrate:fresh --seed
sail artisan permission:cache-reset

# Swagger
sail artisan l5-swagger:generate

# shadcn-vue
npx shadcn-vue@latest add <component>

# Генераторы
sail artisan make:model Release -mfc
sail artisan make:request CreateReleaseRequest
sail artisan make:test ReleaseTest

# Dev
sail up -d && sail npm run dev
sail artisan tinker
sail artisan pail --filter=error
```

## Окружение

```env
APP_ENV=local / staging / production
APP_DEBUG=true                # false в production
DB_CONNECTION=pgsql           # sqlite в тестах
QUEUE_CONNECTION=redis        # sync в тестах
CACHE_DRIVER=redis            # array в тестах
L5_SWAGGER_GENERATE_ALWAYS=true  # только dev
```

Pre-commit хуки:
```bash
git config core.hooksPath .githooks && chmod +x .githooks/pre-commit
```

## Git Workflow

**Conventional Commits:** `feat(releases):` / `fix(auth):` / `docs:` / `refactor:` / `test:`

```
main ← develop ← feature/название | fix/название | release/версия
```

**Коммиты только с разрешения пользователя.**

## Антипаттерны

### Backend
- ❌ Бизнес-логика в контроллерах → выноси в Action
- ❌ `try/catch` в контроллерах → кидай кастомные исключения
- ❌ N+1 → `with()` / `withCount()`
- ❌ Массовые операции в цикле → `whereIn(...)->update(...)`

### Frontend
- ❌ Изменение props напрямую (`props.x++`) → `emit('update:x', value)`
- ❌ `ref()` для объектов → `reactive()`
- ❌ Мутации в computed (`sort()`) → `[...arr].sort()`
- ❌ Создание Button/Card/Input вручную → `npx shadcn-vue@latest add <component>`
- ❌ `class="border-red-500 text-red-600"` в формах → `border-destructive text-destructive`
- ❌ Кастомный `useToast.js` → `import { toast } from 'vue-sonner'`

## Безопасность

- **CSRF** — Inertia добавляет автоматически
- **XSS** — `{{ }}` безопасно; `v-html` только с `sanitizeHtml()`
- **SQL Injection** — параметризованные запросы или ORM, никогда конкатенация строк
- **Mass Assignment** — всегда `$fillable` / `$guarded` + `$request->validated()`

## Ссылки

[Laravel 12](https://laravel.com/docs/12.x) · [Inertia.js](https://inertiajs.com/) · [Vue 3](https://vuejs.org/) · [shadcn-vue](https://www.shadcn-vue.com/) · [Tailwind](https://tailwindcss.com/) · [Pest](https://pestphp.com/) · [Spatie Data](https://spatie.be/docs/laravel-data) · [Spatie Permission](https://spatie.be/docs/laravel-permission) · [l5-swagger](https://github.com/DarkaOnLine/L5-Swagger) · [OpenAPI 3.0](https://swagger.io/specification/)
