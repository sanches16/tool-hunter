# TOOL HUNTER — FINAL MASTER SPEC & ITERATION 0 HANDOFF

**Version:** 1.0.0-READY  
**Status:** READY FOR DEVELOPMENT  
**Language:** RU  
**Initial use case:** персональный каталог товаров + поиск предложений на Avito  
**Primary platform:** Web / PWA  
**Primary user:** один приватный пользователь  
**Development mode:** small-spec iterations with human review gate  
**Canonical principle:** application is the source of truth

---

# 0. Назначение документа

Этот документ объединяет:

- продуктовую концепцию;
- архитектурные решения;
- границы MVP;
- модель данных;
- правила UX;
- правила поиска;
- инфраструктуру;
- безопасность;
- стратегию тестирования;
- стратегию развития;
- финальное задание на Iteration 0.

Документ должен использоваться как главный источник требований для начала разработки.

После старта разработки изменения этого документа допускаются только явно, с фиксацией в CHANGELOG / ADR / новой версии спецификации.

---

# 1. Что мы строим

Tool Hunter — приватное универсальное приложение для управления товарами и вещами, которые пользователь хочет:

- найти;
- купить;
- сравнить;
- мониторить;
- сохранить;
- отслеживать по цене;
- пометить как купленные;
- архивировать;
- удалить.

Первый практический сценарий:

- инструменты Milwaukee / DeWalt / Daewoo;
- поиск на Avito;
- регион Москва;
- анализ цены и качества предложения.

Архитектура не должна зависеть:

- от Milwaukee;
- от категории «инструменты»;
- от Avito;
- от конкретной AI-модели;
- от Telegram;
- от одного marketplace.

Позже тем же приложением можно управлять:

- электроникой;
- камерами;
- товарами для ребёнка;
- автотоварами;
- мебелью;
- автомобилями;
- другими покупками;
- другими marketplace.

---

# 2. Главный принцип

## Tool Hunter — Source of Truth

Именно Tool Hunter хранит:

- каталог;
- изображения;
- приоритеты;
- ручной порядок;
- статусы;
- цены;
- историю цен;
- поисковые запросы;
- найденные объявления;
- историю поисков;
- архив;
- покупки;
- результаты импорта;
- аудит.

AI-агенты не являются базой данных.

AI может помогать:

- создавать поисковые запросы;
- искать объявления;
- анализировать объявления;
- сравнивать цены;
- готовить рекомендации.

Но состояние приложения существует независимо от AI.

---

# 3. Что входит в MVP

MVP должен позволять:

1. открыть каталог на iPhone и desktop;
2. видеть все текущие 15 канонических позиций;
3. видеть реальные изображения;
4. видеть пиктограммы категорий;
5. видеть название, бренд, модель;
6. менять priority 1–5★;
7. менять ручной порядок;
8. использовать «В начало», ↑, ↓;
9. добавлять новую позицию;
10. редактировать позицию;
11. загружать изображения;
12. архивировать;
13. восстанавливать;
14. помещать в корзину;
15. удалять навсегда из корзины;
16. отмечать как purchased;
17. хранить reference / target / buy-now price;
18. хранить marketplace queries;
19. импортировать результаты поиска;
20. хранить историю цен объявлений;
21. экспортировать задания для внешнего агента;
22. работать с приватным доступом;
23. сохранять данные после restart / redeploy;
24. иметь backup + доказанный restore.

---

# 4. Что НЕ входит в MVP

Не делать в первой версии:

- несколько пользователей;
- публичную регистрацию;
- несколько Workspace в UI;
- tags;
- Telegram Mini App;
- PWA push notifications;
- email alerts;
- несколько marketplace в UI;
- автоматический headless Avito scraper на VPS;
- хранение Avito cookies на сервере;
- хранение Avito password на сервере;
- полностью автономный multi-agent orchestrator;
- Kubernetes;
- Redis;
- MinIO;
- Kafka;
- Elasticsearch;
- микросервисы.

---

# 5. Основные пользовательские сценарии

## 5.1 Добавить товар

Пользователь нажимает:

`+ Добавить`

Заполняет:

- название;
- бренд;
- модель;
- category;
- фото;
- priority;
- reference price;
- target price;
- buy-now price;
- поисковые запросы;
- notes.

После сохранения карточка появляется в каталоге.

---

## 5.2 Изменить priority

Пользователь задаёт:

`★★★★★`

Карточка перестраивается согласно:

`priority DESC, manual_order ASC, created_at ASC`

Если пользователь присваивает позиции рейтинг, который уже есть у других элементов, позиция становится после уже существующих элементов этой priority-группы.

---

## 5.3 Изменить ручной порядок

Пользователь использует:

- `В начало`
- `↑`
- `↓`

Manual order должен сохраняться при:

- перезапуске;
- refresh;
- смене сортировки;
- возвращении к сортировке по priority.

---

## 5.4 Архивировать

Позиция исчезает из live catalog, но сохраняет:

- изображения;
- историю;
- цены;
- объявления;
- notes.

Её можно восстановить.

---

## 5.5 Удалить

Удаление идёт в два этапа:

`live/archived -> trash -> permanent delete`

Permanent delete требует явного подтверждения.

---

## 5.6 Отметить купленной

Устанавливается:

`intent = purchased`

Дополнительно можно сохранить:

- purchased_at;
- purchased_price;
- listing reference;
- notes.

Купленная позиция может оставаться live или быть archived позже.

---

## 5.7 Найти на Avito

Пользователь инициирует SearchRun.

Система формирует structured search task.

В первой живой версии поиск может выполняться вручную внешним агентом, который возвращает JSON.

Позже Local Agent автоматизирует этот процесс.

---

# 6. UX Contract — зафиксированные правила

Эти правила считаются regression requirements.

## 6.1 One model = one item

Одна физическая модель товара = одна позиция.

Разные комплектации не создают отдельные Item автоматически.

Пример:

- tool-only;
- kit;
- battery included;
- charger included;
- case included.

Комплектация относится к объявлению или варианту предложения.

---

## 6.2 Карточка должна содержать

Обязательно:

- пиктограмма;
- реальная миниатюра;
- понятное название.

Пустой placeholder запрещён, если есть canonical image.

---

## 6.3 Priority

Используется:

- ★
- ★★
- ★★★
- ★★★★
- ★★★★★

---

## 6.4 Сортировка

Формула:

`priority DESC, manual_order ASC, created_at ASC`

---

## 6.5 Добавление в существующую priority-группу

Если элемент получает priority N:

`manual_order = max(manual_order среди priority=N) + 1`

---

## 6.6 Manual controls

Обязательно:

- `В начало`
- `↑`
- `↓`

---

## 6.7 Mobile-first

UI должен быть удобен на iPhone.

Touch targets должны быть достаточно крупными.

Desktop должен использовать тот же UI без отдельной кодовой базы.

---

# 7. Информационная архитектура UI

## 7.1 Catalog

Показывает:

- thumbnail;
- pictogram;
- title;
- brand/model;
- priority;
- reference/target/buy-now prices;
- intent;
- quick actions.

Фильтры:

- live;
- archived;
- purchased;
- priority;
- category.

---

## 7.2 Item Detail

Показывает:

- изображения;
- metadata;
- attributes;
- prices;
- queries;
- notes;
- найденные listings;
- price history;
- audit history.

---

## 7.3 Add / Edit Item

Форма создания/изменения.

---

## 7.4 Archive

Отдельный список archived items.

---

## 7.5 Trash

Отдельный список trash.

---

## 7.6 Search Runs

История запусков поиска.

---

## 7.7 Settings

На MVP минимально:

- profile;
- access;
- export;
- backup info.

---

# 8. Архитектурный стиль

Использовать:

`Modular Monolith`

Причины:

- проще разработка;
- проще review;
- проще миграции;
- проще Docker;
- проще тестирование;
- проще backup;
- достаточно для одного пользователя;
- можно масштабировать позже.

Не использовать микросервисы на старте.

---

# 9. Технологический стек

## Application

- Next.js
- TypeScript
- React
- Tailwind CSS

## Database

- PostgreSQL

## ORM / DB layer

Выбрать:

`Drizzle`

Причина:

- SQL migrations легче читать в review;
- меньше скрытой генерации;
- легче аудит изменений схемы агентом.

Использовать обычные SQL migrations.

## Runtime

- Node.js
- Docker
- Docker Compose

## Reverse proxy

На local Iteration 0:

- не обязателен.

На VPS:

- Caddy.

---

# 10. Структура модулей

```text
modules/
  catalog/
  media/
  marketplace/
  search/
  listings/
  pricing/
  auth/
  integrations/
  audit/
  backup/
  notifications/
```

---

# 11. Workspace

Workspace существует в схеме для future-proofing.

На MVP:

- создаётся один default Workspace;
- UI выбора Workspace не существует.

Не делать multi-workspace UI.

---

# 12. Item

Основная сущность.

```text
id UUID
workspace_id

title
brand nullable
model nullable
category_id nullable

description nullable
notes nullable

priority int 1..5
manual_order

intent
retention

attributes JSONB

created_at
updated_at
```

---

# 13. Attributes JSONB

Категорийные поля не должны раздувать Item schema.

Пример:

```json
{
  "platform": "M18",
  "disc_mm": 190,
  "guide_rail": true
}
```

Позже другая категория может использовать:

```json
{
  "resolution": "5.3K",
  "battery_type": "Enduro"
}
```

---

# 14. Две независимые оси состояния

## intent

Показывает смысл товара для пользователя.

### active

Хочу купить, но регулярный мониторинг не ведётся.

### watching

Есть поисковые запросы и товар регулярно отслеживается.

### paused

Товар нужен, но поиск временно приостановлен.

### purchased

Факт покупки.

---

## retention

Показывает жизненный цикл записи.

- live
- archived
- trash

---

# 15. Item lifecycle

Примеры:

- active + live
- watching + live
- paused + live
- purchased + live
- purchased + archived

Permanent delete не является status.

Это destructive operation из trash.

---

# 16. Images

## ItemImage

```text
id
item_id
storage_key

source:
upload
imported
web
generated

original_filename nullable
mime_type
width
height
sha256
is_primary
created_at
```

---

# 17. Image rules

1. canonical image хранится под контролем приложения;
2. не зависеть от внешних URL;
3. strip EXIF/GPS;
4. MIME validation;
5. upload size limit;
6. SHA256;
7. dedupe;
8. original + optimized thumbnail.

---

# 18. Image storage

MVP:

- persistent filesystem volume;
- через `ImageStorage` abstraction.

Позже можно заменить на:

- Backblaze B2;
- S3;
- R2.

---

# 19. Цены

Нужны три цены.

## Reference

Ориентир рынка.

## Target

Хорошая цена.

## Buy-now

Цена, при которой предложение стоит покупать сразу.

---

# 20. ItemPriceTarget

Не хранить цену как вечное поле без истории.

```text
id
item_id

kind:
reference
target
buy_now

amount
currency

observed_at

source_type:
manual
marketplace_sample
imported
ai_estimate

source_note nullable

active
```

---

# 21. Freshness reference price

Reference считается устаревшим через:

`30 дней`

После 30 дней:

- цена не исчезает;
- рядом показывается `ориентир устарел`;
- scoring может продолжать работать, но UI обязан показать stale state.

Reference обновляется только:

- пользователем;
- явным импортом marketplace sample.

Фоновый агент не должен самовольно менять reference price.

---

# 22. Price scoring

Правила должны быть детерминированными.

Если reference актуален:

```text
listing_price <= buy_now  -> SUPER
listing_price <= target   -> GOOD
listing_price <= reference -> NORMAL
listing_price > reference -> EXPENSIVE
```

---

# 23. Suspicious

`SUSPICIOUS` — отдельный флаг.

Не заменяет price label.

Минимальное правило:

- цена < 40% актуального reference

или

- продавец без истории / недостаточно данных согласно детерминированным правилам.

Итог может быть:

`SUPER + SUSPICIOUS`

AI может дополнительно комментировать риск, но не должен быть единственным источником suspicious flag.

---

# 24. Marketplace abstraction

Core Item не содержит Avito-specific fields.

Используется provider interface.

```text
buildSearchUrl()
normalizeListing()
extractExternalId()
deduplicateListing()
validateResult()
```

Первый provider:

`avito`

---

# 25. MarketplaceQuery

```text
id
item_id
provider
query
location
allow_remote_delivery
seller_type_filter nullable
active
created_at
updated_at
```

---

# 26. Search defaults

Для Avito:

- region default = Москва;
- delivery from other regions = optional flag;
- seller type filter существует в модели;
- UI seller filter можно добавить позже.

---

# 27. SearchRun

Строгая сущность.

```text
id
workspace_id
provider

status:
queued
running
completed
failed
cancelled

idempotency_key unique

requested_location

requested_at
deadline_at nullable

started_at nullable
finished_at nullable

triggered_by:
user
schedule
agent

raw_agent_response JSONB nullable

error_code nullable
error_message nullable
```

---

# 28. SearchRunItem

Сохраняет snapshot задания.

```text
search_run_id
item_id

priority_snapshot
query_snapshot
target_price_snapshot
```

---

# 29. Search protocol

Для одного item агент должен:

1. открыть минимум 20 релевантных карточек поиска;
2. проанализировать их;
3. вернуть максимум 5 лучших релевантных объявлений.

---

# 30. Rejected listings

Отвергнутые объявления храним кратко.

```text
external_id
search_run_id
reason
created_at
```

Причины, например:

- wrong_model;
- accessory_only;
- fake_price;
- duplicate;
- suspicious;
- irrelevant;
- unavailable.

Это предотвращает повторный шум.

---

# 31. Search result contract

Результат должен быть JSON.

Использовать versioned JSON Schema:

`schemas/avito-search-result.schema.v1.json`

Если payload не проходит schema validation:

- не делать silent partial import;
- сохранить raw response;
- показать validation error;
- SearchRun пометить failed/invalid result согласно реализации.

---

# 32. Listing

```text
id

provider
external_id nullable

canonical_url

title

condition nullable
completeness nullable

seller_name nullable
seller_rating nullable
seller_reviews nullable
seller_type nullable

location nullable
delivery_info nullable

first_seen_at
last_seen_at

active
suspicious

raw_payload JSONB
```

---

# 33. Listing identity

Главный dedupe key:

`provider + external_id`

Если external_id нет:

1. canonical URL;
2. heuristic fingerprint.

URL не является главным ID.

---

# 34. PriceSnapshot

Цена объявления — историческое наблюдение.

```text
id
listing_id
amount
currency
captured_at
search_run_id nullable
```

Старые значения не перезаписываются.

---

# 35. ItemListing

```text
item_id
listing_id

relevance_score nullable
price_score nullable

recommendation_label:
super
good
normal
expensive

suspicious bool

notes nullable
```

---

# 36. Avito integration — MVP

Сервер не логинится в Avito.

Первый рабочий сценарий:

```text
Tool Hunter
  ↓
export SearchRun JSON
  ↓
external browser agent
  ↓
Avito in user browser session
  ↓
result JSON
  ↓
manual/API import
  ↓
validation
  ↓
dedupe
  ↓
store
```

---

# 37. Avito hard security boundary

На сервере запрещено хранить:

- Avito password;
- Avito cookies;
- Avito session;
- browser profile.

---

# 38. Local Agent — позже

Не делать до Iteration 4.

Позже локальный Agent на Mac сможет:

- poll queued SearchRuns;
- работать с локальным Chrome;
- вернуть JSON на server API.

---

# 39. Authentication strategy

## До VPS

Использовать:

- localhost;
- Tailscale;
- при необходимости SSH tunnel.

Не делать OAuth в Iteration 0.

---

## Первый постоянный remote access

Tailscale.

Это выбранный вариант до появления публичного домена.

---

## После стабилизации

Когда появится необходимость:

- custom domain;
- HTTPS;
- Google OAuth allowlist одного email.

Публичная регистрация всегда выключена.

---

# 40. VPS strategy

VPS не нужен до стабильного Iteration 1.

Порядок:

1. local Mac + Docker;
2. Iteration 0;
3. Iteration 1;
4. открыть через Tailscale с телефона;
5. убедиться, что каталог стабилен;
6. только затем VPS.

---

# 41. Production VPS

Стартово достаточно:

- Linux;
- 2 vCPU;
- 2–4 GB RAM;
- 30–50 GB SSD;
- Docker Compose.

Production containers:

- app;
- postgres;
- caddy.

---

# 42. Domain

Покупка домена не обязательна до стабильного каталога.

Домен нужен позже для:

- стабильного URL;
- TLS;
- OAuth callback;
- Telegram webhook;
- Mini App;
- удобного PWA.

---

# 43. Backup

Backup — foundation.

Нужно backup:

- PostgreSQL;
- media.

---

# 44. Iteration 0 backup

Off-site backup не требуется для принятия Iteration 0.

Нужно доказать:

- DB backup;
- media backup;
- успешный restore.

---

# 45. Перед VPS

До production VPS добавить off-site backup.

Предпочтительно:

- Backblaze B2;
- второй независимый storage.

Не добавлять R2/MinIO «на всякий случай».

---

# 46. Restore test

Тест:

1. seed canonical data;
2. backup;
3. destroy test DB/media;
4. restore;
5. проверить:
   - 15 items;
   - 15 primary images;
   - image hashes;
   - priority;
   - manual order.

---

# 47. PWA

PWA — основной клиент.

Требования:

- responsive;
- manifest;
- installable;
- iPhone;
- desktop.

Offline destructive writes не делать в MVP.

---

# 48. Telegram

Не входит в MVP core.

Позже используется только для notifications.

События:

- SUPER listing;
- price crosses buy-now;
- SearchRun failed.

Не делать email и PWA push одновременно.

Первый notification channel:

`Telegram`

---

# 49. Telegram Mini App

Не делать до стабилизации PWA.

Если понадобится:

- Mini App использует тот же backend/API;
- бизнес-логика не дублируется.

---

# 50. Build Plane — минимальный процесс

Идея multi-agent development сохраняется, но автоматизация не строится раньше продукта.

Роли в репозитории называются абстрактно:

- architect;
- implementer;
- reviewer.

Не использовать названия конкретных моделей как часть архитектуры репозитория.

---

# 51. Build Plane — что делаем сейчас

На первых 2–3 итерациях:

- один Markdown SPEC;
- Git branch;
- implementer делает commit;
- reviewer проверяет diff;
- CI проверяет deterministic tests;
- human approve/merge.

Пока перенос SPEC между агентами может быть ручным.

Это допустимо.

---

# 52. Build Plane — что подготовить заранее

Можно иметь только docs/examples:

```text
docs/agent/
  task-packet.example.json
  result-packet.example.json
  review-packet.example.json
  AGENT_WORKFLOW.md
```

Это документация.

Не делать:

- agentctl;
- автоматическое ожидание агента;
- orchestrator state machine;
- automatic repair loops;
- evidence pipeline;
- auto-merge.

---

# 53. Когда автоматизировать Build Plane

После 2–3 успешных итераций.

Когда:

- repo стабилен;
- CI стабилен;
- формат SPEC стабилен;
- ResultPacket реально используется;
- понятны ручные узкие места.

Тогда можно построить agent bridge.

---

# 54. Human promotion gate

Auto-merge запрещён всегда.

Даже при:

- green CI;
- PASS reviewer.

Merge требует human approval.

---

# 55. Testing strategy

## Iteration 0

Достаточно:

- lint;
- typecheck;
- DB migration test;
- seed test;
- seed idempotency;
- healthcheck;
- backup;
- restore.

Не делать:

- Playwright;
- visual regression;
- UI E2E.

---

## Iteration 1

Добавляются:

- Playwright;
- mobile viewport;
- interaction tests;
- screenshot regression.

---

# 56. Regression requirements после Iteration 1

Release должен падать, если:

- пропали canonical items;
- пропали images;
- blank thumbnails;
- stars не кликаются;
- manual order потерян;
- «В начало» не работает;
- priority algorithm изменился;
- migration теряет данные.

---

# 57. Versioning

Использовать Semantic Versioning.

Обязательно:

- VERSION;
- CHANGELOG.md;
- SQL migrations.

---

# 58. Canonical seed

Текущий accepted catalog из 15 позиций — обязательный seed.

Нужен файл:

`seed/canonical-items.json`

Изображения:

`seed/images/`

Каждая позиция должна иметь стабильный:

`seed_key`

Seed нельзя заменять поиском картинок в интернете.

Если canonical image asset отсутствует:

IMPLEMENTER MUST STOP AND REPORT BLOCKED.

Не использовать внешнюю картинку как молчаливую замену.

---

# 59. Canonical 15 items

Ниже обязательный seed metadata.

## 1

```yaml
seed_key: mw-2521-20
brand: Milwaukee
title: M12 FUEL компактная циркулярная пила
model: 2521-20
search_query: Milwaukee 2521-20
priority: 3
reference_price_rub: 17900
manual_order: 0
pictogram: 🔴
image_asset: seed/images/mw-2521-20.jpg
```

## 2

```yaml
seed_key: mw-2831-20
brand: Milwaukee
title: M18 FUEL погружная пила по шине
model: 2831-20
search_query: Milwaukee 2831-20
priority: 5
reference_price_rub: null
manual_order: 1
pictogram: 🔴
image_asset: seed/images/mw-2831-20.jpg
```

## 3

```yaml
seed_key: mw-2833-20
brand: Milwaukee
title: M18 FUEL циркулярная пила 165 мм
model: 2833-20
search_query: Milwaukee 2833-20
priority: 4
reference_price_rub: null
manual_order: 2
pictogram: 🔴
image_asset: seed/images/mw-2833-20.jpg
```

## 4

```yaml
seed_key: mw-2834-20
brand: Milwaukee
title: M18 FUEL циркулярная пила 184 мм
model: 2834-20
search_query: Milwaukee 2834-20
priority: 4
reference_price_rub: null
manual_order: 3
pictogram: 🔴
image_asset: seed/images/mw-2834-20.jpg
```

## 5

```yaml
seed_key: dewalt-dcs579nt
brand: DeWalt
title: FLEXVOLT 54V дисковая пила
model: DCS579NT
search_query: DeWalt DCS579NT
priority: 3
reference_price_rub: 33500
manual_order: 4
pictogram: 🟡
image_asset: seed/images/dewalt-dcs579nt.jpg
```

## 6

```yaml
seed_key: mw-m18-xc5
brand: Milwaukee
title: M18 REDLITHIUM аккумулятор 5 Ah
model: M18 XC5.0
search_query: Milwaukee M18 XC5.0
priority: 4
reference_price_rub: 5700
manual_order: 5
pictogram: 🔋
image_asset: seed/images/mw-m18-xc5.jpg
```

## 7

```yaml
seed_key: dewalt-dcb118
brand: DeWalt
title: быстрое зарядное устройство
model: DCB118
search_query: DeWalt DCB118
priority: 1
reference_price_rub: 4800
manual_order: 6
pictogram: 🔋
image_asset: seed/images/dewalt-dcb118.jpg
```

## 8

```yaml
seed_key: mw-2505
brand: Milwaukee
title: M12 FUEL Installation Driver 4-в-1
model: 2505
search_query: Milwaukee 2505
priority: 5
reference_price_rub: 19000
manual_order: 7
pictogram: 🔴
image_asset: seed/images/mw-2505.jpg
notes: tool-only около 19000 ₽; kit около 25000 ₽; одна модель = одна позиция
```

## 9

```yaml
seed_key: daewoo-davc-1621li
brand: Daewoo
title: аккумуляторный строительный пылесос
model: DAVC 1621Li SET
search_query: Daewoo DAVC 1621Li SET
priority: 3
reference_price_rub: 14500
manual_order: 8
pictogram: 🟠
image_asset: seed/images/daewoo-davc-1621li.jpg
```

## 10

```yaml
seed_key: dewalt-dcs438b
brand: DeWalt
title: компактная отрезная машина
model: DCS438B
search_query: DeWalt DCS438B
priority: 2
reference_price_rub: 14299
manual_order: 9
pictogram: 🟡
image_asset: seed/images/dewalt-dcs438b.jpg
```

## 11

```yaml
seed_key: mw-m12-ho5
brand: Milwaukee
title: M12 HIGH OUTPUT аккумулятор 5 Ah
model: 48-11-2450
search_query: Milwaukee 48-11-2450
priority: 4
reference_price_rub: 6400
manual_order: 10
pictogram: 🔋
image_asset: seed/images/mw-m12-ho5.jpg
```

## 12

```yaml
seed_key: mw-2522-20
brand: Milwaukee
title: M12 FUEL компактная отрезная машина
model: 2522-20
search_query: Milwaukee 2522-20
priority: 4
reference_price_rub: 13500
manual_order: 11
pictogram: 🔴
image_asset: seed/images/mw-2522-20.jpg
```

## 13

```yaml
seed_key: mw-0970-20
brand: Milwaukee
title: M18 FUEL PACKOUT пылесос
model: 0970-20
search_query: Milwaukee 0970-20
priority: 4
reference_price_rub: 26990
manual_order: 12
pictogram: 🟠
image_asset: seed/images/mw-0970-20.jpg
```

## 14

```yaml
seed_key: diablo-dou5spc
brand: Diablo
title: набор полотен для реноватора, 5 шт.
model: DOU5SPC
search_query: Diablo DOU5SPC
priority: 1
reference_price_rub: 5750
manual_order: 13
pictogram: ⚙️
image_asset: seed/images/diablo-dou5spc.jpg
```

## 15

```yaml
seed_key: mw-blhsb-0
brand: Milwaukee
title: M18 компактная воздуходувка
model: BLHSB-0
search_query: Milwaukee BLHSB-0
priority: 2
reference_price_rub: 14990
manual_order: 14
pictogram: 🟠
image_asset: seed/images/mw-blhsb-0.jpg
```

---

# 60. Seed acceptance rule

После первого seed:

- exactly 15 items.

После второго seed:

- still exactly 15 items.

Не допускается:

- duplicate items;
- duplicate images;
- duplicate variants;
- priority changes;
- manual order changes.

---

# 61. Repository structure — target

```text
/
  app/

  components/

  modules/
    catalog/
    media/
    marketplace/
    search/
    listings/
    pricing/
    auth/
    integrations/
    audit/
    backup/
    notifications/

  db/
    migrations/
    schema/

  seed/
    canonical-items.json
    images/

  tests/
    unit/
    integration/
    e2e/
    visual/

  schemas/

  scripts/

  docs/
    REQUIREMENTS.md
    ARCHITECTURE.md
    SECURITY.md
    DEPLOYMENT.md
    BACKUP_RESTORE.md
    AVITO_AGENT_PROTOCOL.md
    AGENT_WORKFLOW.md

  docker-compose.yml

  .env.example

  CHANGELOG.md

  VERSION
```

---

# 62. Environment variables — base

```text
DATABASE_URL=
APP_URL=
SESSION_SECRET=

MEDIA_ROOT=/data/media
MAX_UPLOAD_MB=20

BACKUP_ROOT=/data/backups
```

Later:

```text
BOOTSTRAP_ADMIN_EMAIL=
AI_INGEST_TOKEN=
TELEGRAM_BOT_TOKEN=
TELEGRAM_CHAT_ID=
```

Запрещены:

```text
AVITO_PASSWORD
AVITO_COOKIE
AVITO_SESSION
```

---

# 63. Iteration plan

## Iteration 0 — Foundation

Только foundation.

## Iteration 1 — Catalog Core

Catalog UI + priority/manual order + iPhone.

## Iteration 2 — CRUD + Lifecycle

Create/edit/archive/trash/purchased/images.

## Iteration 3 — Search Domain

SearchRun/listings/price history/import JSON.

## Iteration 4 — Avito Agent

Live external/local browser workflow.

## Iteration 5 — Telegram Alerts

SUPER / buy-now / SearchRun failure.

---

# 64. FINAL IMPLEMENTATION HANDOFF

# SPEC-ITER0-FINAL — FOUNDATION

**Status:** READY FOR IMPLEMENTATION

---

## 64.1 Goal

Создать стабильный canonical repository и доказать, что:

- проект запускается;
- PostgreSQL работает;
- миграции работают;
- canonical 15 items импортируются;
- images импортируются;
- повторный seed не создаёт дубли;
- данные персистентны;
- DB/media можно backup;
- DB/media можно restore;
- foundation проверяется автоматическими тестами.

---

## 64.2 In Scope

### Repository

Создать:

- Git repository;
- README;
- VERSION;
- CHANGELOG;
- docs.

### Application

Создать:

- Next.js;
- TypeScript;
- minimal server-rendered verification page;
- health endpoint.

### Database

PostgreSQL.

Drizzle.

SQL migrations.

Таблицы только для foundation:

- Workspace;
- Item;
- ItemImage;
- ItemPriceTarget при необходимости для сохранения seed reference prices.

НЕ создавать:

- Listing;
- SearchRun;
- PriceSnapshot marketplace;
- RejectedListing.

### Docker Compose

Iteration 0 local:

- app;
- postgres.

Caddy не обязателен.

### Media

- persistent media volume;
- ImageStorage interface;
- filesystem implementation.

### Canonical Seed

Создать:

`seed/canonical-items.json`

Добавить 15 canonical images.

Seed должен быть idempotent.

### Backup

Создать команды/scripts:

- backup DB;
- backup media;
- restore DB;
- restore media;
- restore-test.

### Tests

Обязательно:

- lint;
- typecheck;
- migrations from empty DB;
- seed count;
- seed idempotency;
- image existence;
- image hash;
- DB health;
- backup/restore.

---

## 64.3 Out of Scope

Запрещено делать в Iteration 0:

- full catalog UI;
- interactive stars;
- reorder;
- CRUD;
- archive UI;
- trash UI;
- purchased UI;
- auth/OAuth;
- SearchRun;
- Listing;
- marketplace automation;
- Claude integration;
- Telegram;
- Caddy production deployment;
- VPS deployment;
- agentctl;
- autonomous multi-agent orchestrator;
- E2E Playwright;
- visual regression;
- PR automation;
- auto-merge.

---

## 64.4 Required Item fields for Iteration 0

```text
id
seed_key unique

workspace_id

title
brand
model
category

priority
manual_order

intent
retention

attributes JSONB
notes

created_at
updated_at
```

Constraints:

```text
priority between 1 and 5
```

Intent:

- active
- watching
- paused
- purchased

Retention:

- live
- archived
- trash

Seed:

```text
intent = active
retention = live
```

---

## 64.5 ItemImage

```text
id
item_id
storage_key
source
mime_type
width
height
sha256
is_primary
created_at
```

Requirements:

- all 15 seed items have primary image;
- SHA256 stored;
- repeated seed does not duplicate media;
- images copied into application-controlled storage.

---

## 64.6 Verification page

Minimal verification page.

Server-rendered.

Must display:

- exactly 15 items;
- image;
- pictogram;
- title;
- brand/model;
- priority;
- manual order.

No interactive behavior required.

Page must remain readable even if client hydration fails.

---

## 64.7 Backup/restore test

Automated or scripted sequence:

1. migrate;
2. seed;
3. verify 15;
4. backup DB;
5. backup media;
6. destroy test data;
7. restore;
8. verify again.

After restore:

- item count = 15;
- primary image count = 15;
- seed keys preserved;
- image hashes preserved;
- priority preserved;
- manual order preserved.

---

## 64.8 Acceptance Criteria

### AC-01

Fresh clone can install dependencies.

### AC-02

`docker compose up` starts app + postgres.

### AC-03

PostgreSQL is not exposed publicly beyond local development requirement.

### AC-04

Fresh SQL migration succeeds.

### AC-05

First seed produces exactly 15 unique Items.

### AC-06

Second seed leaves exactly 15 Items.

### AC-07

No duplicate `seed_key`.

### AC-08

Every canonical Item has a valid primary image.

### AC-09

Repeated seed does not duplicate image content.

### AC-10

Verification page shows exactly 15 cards.

### AC-11

Verification page is server-rendered and does not depend on JS to construct the list.

### AC-12

Persistent DB data survives app container recreation.

### AC-13

Persistent media survives app container recreation.

### AC-14

DB backup succeeds.

### AC-15

Media backup succeeds.

### AC-16

Restore test succeeds.

### AC-17

Restored DB contains exactly 15 canonical items.

### AC-18

Restored media hashes match pre-backup hashes.

### AC-19

Lint passes.

### AC-20

Typecheck passes.

### AC-21

Migration test passes.

### AC-22

Seed idempotency test passes.

### AC-23

No SearchRun / Listing / Telegram / Avito code is introduced.

### AC-24

No Avito credentials/secrets appear anywhere in repo.

---

## 64.9 Required commands

Document actual equivalents of:

```text
install
dev
build
lint
typecheck
test
db:migrate
db:seed
backup:db
backup:media
restore:test
```

---

## 64.10 Required artifacts

Implementer must produce:

- repository;
- README.md;
- VERSION;
- CHANGELOG.md;
- docs/ARCHITECTURE.md;
- docs/SECURITY.md;
- docs/BACKUP_RESTORE.md;
- docker-compose.yml;
- .env.example;
- Drizzle schema;
- SQL migrations;
- canonical-items.json;
- canonical seed images;
- seed script;
- backup scripts;
- restore test;
- tests;
- RESULT-ITER0-FINAL.md.

---

## 64.11 Result report

`RESULT-ITER0-FINAL.md` must contain:

- base commit;
- head commit;
- changed files;
- chosen package versions;
- commands executed;
- migration result;
- seed result;
- first seed item count;
- second seed item count;
- primary image count;
- backup result;
- restore result;
- lint result;
- typecheck result;
- test result;
- deviations;
- known limitations;
- blockers.

---

## 64.12 Stop condition

После:

1. implementation;
2. tests;
3. backup/restore;
4. result report;
5. commit;

IMPLEMENTER MUST STOP.

Не начинать Iteration 1.

---

# 65. Development process after Iteration 0

Первые итерации выполняются вручную:

```text
Architect creates narrow SPEC
        ↓
Implementer changes isolated branch
        ↓
tests
        ↓
Result report + commit
        ↓
Reviewer checks diff
        ↓
Human approve
        ↓
merge
```

Automation of this flow is postponed until the process itself is proven stable.

---

# 66. Locked Decisions

Считать принятыми до появления новой явной архитектурной причины:

1. Tool Hunter = source of truth.
2. PWA = primary UI.
3. Modular Monolith.
4. Next.js + TypeScript.
5. PostgreSQL.
6. Drizzle + SQL migrations.
7. Docker Compose.
8. Workspace exists in schema but no Workspace UI in MVP.
9. No tags in MVP.
10. Item has `attributes JSONB`.
11. Item state split into `intent` + `retention`.
12. `paused` is required.
13. Three price levels are required.
14. Reference becomes stale after 30 days.
15. Price scoring is deterministic.
16. Suspicious is a separate deterministic flag.
17. One model = one item.
18. Completeness belongs to Listing, not Item identity.
19. Search agent inspects >=20 cards.
20. Search result returns <=5 relevant listings.
21. Rejected listings are stored compactly.
22. Default Avito region = Moscow.
23. Remote delivery = query flag.
24. Server never stores Avito credentials/session.
25. Local Agent is postponed to Iteration 4.
26. Tailscale is first persistent remote-access method.
27. VPS only after stable Iteration 1.
28. Domain/OAuth postponed.
29. Off-site backup required before VPS production.
30. Telegram is first notification channel later.
31. Build Plane automation postponed until 2–3 successful manual iterations.
32. Git files may later be used as task queue.
33. PR is allowed.
34. Auto-merge is forbidden.
35. Human is final promotion gate.

---

# 67. Definition of Done for Iteration 0

Iteration 0 считается завершённым только когда:

- repository exists;
- Docker local starts;
- DB migrates from zero;
- seed creates exactly 15 items;
- second seed still has exactly 15;
- 15 canonical images exist;
- image hashes recorded;
- DB persists;
- media persists;
- DB backup works;
- media backup works;
- restore is proven;
- verification page shows all 15;
- lint/typecheck/tests are green;
- RESULT-ITER0-FINAL exists;
- commit exists;
- implementer stops.

---

# 68. Next step after approval

Этот документ отдаётся implementer как единственный master handoff для начала проекта.

Implementer выполняет только:

`SPEC-ITER0-FINAL`

После завершения:

- reviewer проверяет RESULT;
- reviewer проверяет diff;
- reviewer проверяет tests;
- human принимает решение о merge;
- только затем формируется SPEC Iteration 1.

