# Tool Hunter — подробное описание проекта для человека

**Версия описания:** 1.0.0 · **Дата сверки:** 11 октября 2026, Europe/Moscow.

**Главная мысль:** в рамках Tool Hunter мы строим приватное приложение для планирования покупок и одновременно разрабатываем переиспользуемую мультиагентную платформу разработки. Tool Hunter — первый практический проект для её проверки. Первый продуктовый сценарий — инструменты и Avito в Москве. Сейчас главная трудность — автоматическая передача и проверка шагов между Claude и GPT; полноценный пользовательский каталог в каноническом репозитории ещё не реализован.

Это описание объединяет продуктовые требования, историю решений, фактическое состояние GitHub и бэклог. Оно не заменяет утверждённые спецификации и не разрешает запуск следующей итерации. Техническая версия для AI-разработчика: [CURSOR_CONTEXT_RU.md](CURSOR_CONTEXT_RU.md).

## Содержание

1. [Зачем нужен проект](#1-зачем-нужен-проект)
2. [Что получит пользователь](#2-что-получит-пользователь)
3. [Модель продукта и правила](#3-модель-продукта-и-правила)
4. [Архитектура и инфраструктура](#4-архитектура-и-инфраструктура)
5. [Три направления работы](#5-три-направления-работы)
6. [Точная стадия на дату сверки](#6-точная-стадия-на-дату-сверки)
7. [Что уже доказано в PoC](#7-что-уже-доказано-в-poc)
8. [Как мы разрабатываем](#8-как-мы-разрабатываем)
9. [История и причины смены подхода](#9-история-и-причины-смены-подхода)
10. [Подробный бэклог](#10-подробный-бэклог)
11. [Дорожная карта и критерии готовности](#11-дорожная-карта-и-критерии-готовности)
12. [Канонический каталог](#12-канонический-каталог)
13. [Риски и открытые решения](#13-риски-и-открытые-решения)
14. [Источники и обновление описания](#14-источники-и-обновление-описания)

## 1. Зачем нужен проект

### 1.1 Практическая проблема

Список желаемых покупок, фотографии, модели, ссылки, цены и обсуждения с AI легко оказываются в разных местах. Трудно понять, какой инструмент нужен первым, какая цена хорошая, какое объявление уже проверяли и что куплено. При повторном обращении к агенту приходится заново передавать контекст. История чата становится неудобным хранилищем данных.

Tool Hunter должен собрать эту информацию в одном приложении. Пользователь открывает каталог на iPhone или компьютере, меняет приоритет, смотрит предложения и историю цен, принимает решение о покупке. Если AI-провайдер недоступен или заменён другим, каталог и накопленные данные продолжают существовать.

Первый пользователь — один владелец с приватным доступом. Это персональный продукт. Публичная регистрация и несколько пользователей не входят в начальный MVP.

### 1.2 Две цели

**Продуктовая цель:** создать удобный и устойчивый инструмент для управления покупками: от «хочу найти» до «куплено», с предложениями, ценами, архивом и восстановлением данных.

**Инженерная цель:** построить переиспользуемую мультиагентную платформу разработки для Tool Hunter и следующих pet-проектов. Разные агенты выполняют роли архитектора, исполнителя и независимого ревьюера; платформа сохраняет требования и решения в Git, передаёт работу между ролями и подтверждает результат воспроизводимыми проверками. Продолжить работу должно быть возможно без полной истории чата. Владелец отдельно подтвердил эту цель 11 октября 2026.

Проверка инженерной цели сейчас выполняется через `PLATFORM-POC-001`: небольшое приложение с PostgreSQL и endpoint проверки состояния. Это промежуточный эксперимент перед полной продуктовой Iteration 0.

### 1.3 Что означает «Tool Hunter — source of truth»

Приложение хранит каталог, фотографии, приоритеты, порядок, статусы, цены, запросы, объявления, историю поиска, покупок и аудита. AI помогает искать и анализировать; его ответ становится данными только после проверки и импорта. Сообщение агента не заменяет запись в базе, результат теста или решение владельца.

## 2. Что получит пользователь

### 2.1 Основной сценарий

1. Открыть приватное приложение на телефоне или компьютере.
2. Увидеть 15 исходных позиций с настоящими фотографиями, пиктограммами, названиями и моделями.
3. Выбрать приоритет от одной до пяти звёзд и расположить покупки в удобном порядке.
4. Добавить собственную позицию, фото, заметки и ценовые ориентиры.
5. Подготовить поиск предложений по конкретной модели.
6. Получить проверенные объявления, сравнить цену, комплектацию и риск.
7. Сохранить покупку, архивировать позицию или переместить в корзину.
8. Вернуться позже с любого устройства и увидеть сохранённое состояние.

Эти шаги описывают целевой продукт. Их наличие в master-spec не означает, что они уже работают в текущем PoC.

### 2.2 Основные экраны

| Экран | Для чего нужен | Что показывает или позволяет |
| --- | --- | --- |
| Каталог | Быстро выбрать следующую покупку | Фото, пиктограмму, название, модель, звёзды, цены, состояние и быстрые действия |
| Карточка товара | Собрать всю информацию о модели | Изображения, параметры, заметки, запросы, объявления, историю цен и аудита |
| Добавление / редактирование | Поддерживать собственный список | Название, бренд, модель, категорию, фото, приоритет, цены, запросы, заметки |
| Архив | Убрать позицию из основного списка с сохранением истории | Архивные позиции и восстановление |
| Корзина | Снизить риск случайной потери данных | Удалённые позиции и подтверждаемое окончательное удаление |
| Поиски | Понять, что и когда искали | Запуски, состояние, результаты и причины ошибок |
| Настройки | Управлять доступом и сохранностью | Профиль, экспорт, доступ и сведения о резервных копиях |

### 2.3 Границы MVP

В master-spec MVP включает приватный каталог, управление позициями, фотографии, приоритет и порядок, три ценовых уровня, запросы поиска, импорт результатов, историю цен, сохранность данных и доказанный restore.

За пределами первой версии: публичная регистрация, несколько пользователей, выбор нескольких Workspace, теги, Telegram Mini App, email и PWA push, несколько marketplace в интерфейсе, серверный headless scraper Avito, хранение Avito cookies/password, Kubernetes, Redis, MinIO, Kafka, Elasticsearch и микросервисы.

Telegram notifications вынесены в позднюю Iteration 5. Telegram Mini App — отдельный возможный следующий клиент после стабилизации PWA. Универсальность архитектуры не означает реализацию всех интеграций сразу.

## 3. Модель продукта и правила

### 3.1 Товар и объявление — разные сущности

**Item** — модель товара, которую пользователь хочет найти или уже купил. **Listing** — конкретное предложение продавца. Tool-only, kit, аккумулятор, зарядка и кейс относятся к комплектации предложения. Они не должны автоматически создавать несколько товаров для одной физической модели.

Например, Milwaukee 2505 остаётся одной позицией, даже если одно объявление продаёт только инструмент, а другое — комплект. Цена и комплектация сравниваются на уровне объявлений.

### 3.2 Две независимые оси состояния

| Ось | Значения | Смысл |
| --- | --- | --- |
| `intent` | `active`, `watching`, `paused`, `purchased` | Хочу купить; отслеживаю; временно приостановил поиск; купил |
| `retention` | `live`, `archived`, `trash` | В основном каталоге; в архиве; в корзине |

Купленную позицию можно оставить в каталоге или отдельно архивировать: `purchased + live` и `purchased + archived` допустимы. `paused` прекращает поиск, сохраняя интерес к товару. Окончательное удаление — операция из корзины с явным подтверждением, а не ещё один статус.

В раннем прототипе использовалась упрощённая ось `active/purchased/archived`. Для нового продукта master-spec определяет более полную модель; старую схему нельзя переносить без явной миграции.

### 3.3 Приоритет и ручной порядок

Приоритет — целое число 1–5. Целевая сортировка: `priority DESC, manual_order ASC, created_at ASC`. При присвоении существующего приоритета позиция должна становиться после уже имеющихся элементов этой группы. Контролы «В начало», ↑ и ↓ обязательны; ручной порядок сохраняется после refresh, restart и переключения сортировки.

Точный смысл перемещения между priority-группами, обновление порядка и обработку конкурирующих изменений нужно зафиксировать в спецификации Catalog Core и проверить тестами. Нельзя незаметно изменить принятый UX из-за удобства реализации.

### 3.4 Три уровня цен и их история

| Цена | Значение для пользователя |
| --- | --- |
| `reference` | Рыночный ориентир |
| `target` | Хорошая цена, к которой стремимся |
| `buy_now` | Порог особенно привлекательного предложения |

Ценовые цели хранят источник и время наблюдения. Reference становится устаревшим через 30 дней: значение остаётся, но интерфейс показывает «ориентир устарел». Фоновый агент не меняет reference самовольно; обновление выполняет пользователь или явный импорт marketplace sample.

Сравнение должно быть детерминированным. При актуальном reference: цена ≤ buy-now — `SUPER`; иначе ≤ target — `GOOD`; иначе ≤ reference — `NORMAL`; выше reference — `EXPENSIVE`. Правила для отсутствующих порогов и stale reference требуют уточнения в спецификации pricing.

`SUSPICIOUS` — отдельный флаг. Минимальное правило в master-spec: цена ниже 40% актуального reference; также предусмотрены правила недостаточных сведений о продавце. Предложение может быть одновременно `SUPER + SUSPICIOUS`. Комментарий AI дополняет оценку, но не служит её единственным основанием.

Цена объявления записывается как **PriceSnapshot** с датой и ссылкой на запуск поиска. Новое наблюдение не перезаписывает старое.

### 3.5 Поиск и импорт

Первый marketplace — Avito, регион по умолчанию — Москва. Доставка из других регионов — отдельный флаг запроса. Поля продавца и комплектации находятся в модели предложения; Item не привязан к Avito.

**SearchRun** — самостоятельный запуск поиска со статусом `queued/running/completed/failed/cancelled`, уникальным idempotency key, временем, провайдером и инициатором. SearchRunItem сохраняет snapshot задания: товар, приоритет, запрос и целевую цену на момент запуска.

Внешний агент должен открыть минимум 20 релевантных карточек поиска и вернуть максимум 5 лучших подходящих объявлений на товар. Нехватку реальных результатов нельзя компенсировать выдуманными предложениями; порядок обработки такого случая нужно уточнить в контракте интеграции.

Предполагаемый первый поток:

```text
Tool Hunter экспортирует SearchRun JSON
→ внешний агент работает в браузерной сессии пользователя
→ возвращает JSON
→ пользователь/API импортирует результат
→ schema validation
→ дедупликация
→ сохранение объявлений и истории цен
```

Главный идентификатор объявления — `provider + external_id`. При отсутствии external_id применяются canonical URL и затем heuristic fingerprint. Отвергнутые объявления сохраняются компактно с причиной, чтобы не повторять шум.

Невалидный payload не должен незаметно частично импортироваться. Master-spec предусматривает versioned JSON Schema, сохранение ответа и понятную ошибку. Ограничения хранения raw response и очистка приватных данных должны быть согласованы до реализации.

### 3.6 Изображения и сохранность

Канонические фото хранятся под контролем приложения. Предусмотрены MIME validation, лимит загрузки, удаление EXIF/GPS, SHA-256, дедупликация и thumbnail. Первая реализация ImageStorage — persistent filesystem volume. Переход на B2/S3/R2 возможен позже через тот же интерфейс.

Нет канонического изображения — исполнитель сообщает BLOCKED. Поиск похожей картинки в интернете не является допустимой молчаливой заменой исходного asset.

## 4. Архитектура и инфраструктура

### 4.1 Целевой продукт

Выбран **модульный монолит**: одна кодовая база с понятными границами catalog, media, marketplace, search, listings, pricing, auth, integrations, audit, backup и notifications.

Master-spec определяет Next.js, TypeScript, React, Tailwind CSS, PostgreSQL, Drizzle и обычные SQL migrations. Runtime — Node.js и Docker Compose. Один default Workspace существует в схеме, но отдельного выбора Workspace в MVP нет. Категорийные параметры хранятся в `attributes JSONB`.

Это целевая архитектура продукта. В текущем PoC используются Next.js/TypeScript/PostgreSQL и прямой драйвер `pg`; ORM, таблицы домена и миграции исключены из его scope. Добавление Drizzle сейчас не требуется для завершения health PoC.

### 4.2 Порядок запуска

1. Локальный Mac + Docker: PoC, затем полноценная Iteration 0.
2. Catalog Core и проверка на iPhone.
3. Первый постоянный удалённый доступ — Tailscale; при необходимости SSH tunnel.
4. VPS после стабильной Iteration 1 и подтверждённой сохранности.
5. Позже домен, TLS/Caddy и, при необходимости, OAuth allowlist одного email.

Master-spec даёт стартовый ориентир VPS: Linux, 2 vCPU, 2–4 GB RAM, 30–50 GB SSD, контейнеры app/postgres/caddy. Это проектное предположение, не покупка и не подтверждённый production sizing.

### 4.3 Backup — часть foundation

Нужно сохранять PostgreSQL и media вместе и доказать восстановление на изолированном тестовом окружении. После restore должны совпасть 15 товаров, 15 primary images, seed keys, hashes, приоритеты и ручной порядок.

Для приёмки Iteration 0 достаточно локального backup/restore. До production VPS требуется off-site backup в независимом хранилище. Наличие Docker volume или архива без restore-test не доказывает восстанавливаемость.

### 4.4 Границы доступа

Сервер никогда не хранит Avito password, cookies, session или браузерный профиль. Первый поиск выполняется во внешнем пользовательском браузере. Local Agent на Mac отложен до Iteration 4.

PWA — основной клиент на iPhone и desktop. Offline destructive writes не входят в MVP. Telegram не должен становиться вторым самостоятельным backend с дублированной бизнес-логикой.

## 5. Три направления работы

Платформа разработки — самостоятельный ожидаемый результат работы в рамках проекта. Tool Hunter служит её первым предметным испытанием: вместо абстрактного демо берётся реальный foundation-срез приложения. Платформу предполагается затем использовать для других pet-проектов, сохранив Git/Markdown, SDD, независимые проверки и контроль владельца.

| Направление | Что проверяем или строим | Результат |
| --- | --- | --- |
| Продукт Tool Hunter | Каталог, покупки, поиск, цены, сохранность | Работающее приватное приложение |
| Мультиагентная платформа / PLATFORM-POC-001 | Foundation health и доказуемый SDD-процесс на Tool Hunter | Переиспользуемая методика и инструменты разработки, проверенные реальным срезом |
| AGENT-LOOP-001 | Передачу ограниченных задач между Claude и reviewer через GitHub | Проверенный механизм handoff без ручной пересылки каждого сообщения |

Эти направления связаны, но их готовность не взаимозаменяема. Установка watcher не создаёт каталог. Green health CI не доказывает backup/restore. Наличие master-spec не означает одобрение следующей продуктовой итерации.

## 6. Точная стадия на дату сверки

### 6.1 Канонический GitHub

Репозиторий: [sanches16/tool-hunter](https://github.com/sanches16/tool-hunter), приватный. Состояние до публикации настоящего пакета документации:

| Объект | Проверенное состояние |
| --- | --- |
| `main` | `0dbbd728643e1025100cdf29d07864be60fb6642`; setup, конституция, intent PoC и Spec Kit integrations; кода приложения нет |
| `poc/platform-poc-001` | `c372a9434f9142bfc075ac8d6df0d4f3aa7a726c`; planning и замороженный экспериментальный workflow |
| `poc/platform-poc-001-incremental` | `170f838ac583db4de0179450ac3b08c863864e7b`; реализованный health-срез, Docker, тесты, CI и README |
| [PR #2](https://github.com/sanches16/tool-hunter/pull/2) | OPEN, не draft, не merged; head — incremental, base — `poc/platform-poc-001`, **не main** |
| `docs/agent-loop-smoke-v13` | На момент сверки указывает на исходный main; ветка сама по себе не доказывает smoke-test |
| Последняя принятая итерация | D3C1 — синхронизация README; APPROVE для `170f838…` |
| Следующее записанное задание | D3C2 — fresh checkout proof без изменений файлов |
| Финальная приёмка PoC | Не найдена в проверенных GitHub records |

После этой публикации main получает документацию и исходную master-spec как reference. Публикация описания не переносит код PoC, не сливает PR #2 и не завершает его приёмку.

### 6.2 Что отсутствует в проверенном candidate tree

В дереве `170f838…` нет `PLATFORM-POC-001-RESULT.md`, versioned `docs/poc/evidence/<sha>/`, `RESUME_IMPLEMENTER.md`, `RESUME_REVIEWER.md` и `CONVERGE.md`. Не найдены final human acceptance и завершённый handoff D3C2 в Issue #1.

Это означает «не подтверждено в исследованном GitHub», а не утверждение об отсутствии любого локального эксперимента. GitHub не показывает живые процессы Claude, ignored run state или текущее содержимое конфигурации на Mac.

### 6.3 Состояние автоматического цикла

Последний audit в [Issue #3](https://github.com/sanches16/tool-hunter/issues/3#issuecomment-6043211492): kit **1.3.1**, `READY_FOR_SMOKE`; `dry_run=true`, `headless_permissions_verified=false`, `sandbox_required=true`. Отчёт содержит PASS 28/28 tests, в том числе 6 реальных sandbox tests на dummy files, и PASS doctor для idle, занятого lock и синтетической pause.

Не подтверждены полная реальная сессия Claude в sandbox, model connectivity через broker, reviewer identity/app, token prerequisite, throwaway PR protocol, STOP-during-run и первый live descendant CAS push + HANDOFF. Поэтому installed/READY_FOR_SMOKE не равно live/accepted.

Branch API на дату сверки показывает `main.protected=false`. Защита main — один из prerequisites checklist автоматизации. В этой публикации настройки доступа и автоматизаций не меняются.

### 6.4 Ранний web-прототип

6 октября был начат отдельный перенос HTML v0.1.2 в web-приложение. Сохранены исходный HTML, 15 карточек и 15 извлечённых фото; написаны доменная модель, черновые API и миграция D1. Первый экран/API собирались, но управление UI, PWA, полный экспорт и проверки не были завершены. Работа была поставлена на паузу.

Это историческая заготовка в отдельной локальной папке, а не код нынешнего `sanches16/tool-hunter`. Её D1/R2/Sites и упрощённая модель статуса не заменяют позднюю master-spec PostgreSQL/Drizzle. Повторное использование возможно только после отдельного сравнения и review.

## 7. Что уже доказано в PoC

### 7.1 Поведение endpoint

Каждый `GET /api/health` выполняет новую SQL-операцию `SELECT 1 AS ok` на настроенном PostgreSQL. Предыдущий успешный ответ не используется как доказательство текущего состояния.

| Условие | Ответ |
| --- | --- |
| Приложение отвечает, SQL успешен | HTTP 200, `{"status":"ok","application":"ok","database":"ok"}` |
| Приложение отвечает, конфигурация/соединение/SQL недоступны | HTTP 503, `{"status":"degraded","application":"ok","database":"unavailable"}` |
| Приложение остановлено | HTTP-ответа нет |

JSON имеет ровно три поля; `Cache-Control: no-store`. Общий внутренний бюджет probe — 4 секунды; внешний acceptance bound — ≤5 секунд в локальной проверочной среде. Восстановление базы обнаруживается следующей проверкой без restart приложения.

### 7.2 Проверки

Реализованы независимые команды `npm run lint`, `npm run typecheck`, `npm run build`, `npm test`, `npm run verify:startup`. Docker/Compose обязателен для integration/startup; его отсутствие вызывает FAIL, не skip.

Покрытие: 10 здоровых ответов → 10 после остановки DB → 10 после восстановления; неизменность app container ID/StartedAt; silent TCP listener и очистка sockets; отсутствующие/пустые/невалидные настройки; неправильный пароль; cold refused DB; focused query/deadline/result cases; контроль, отклоняющий ложный full-health.

Независимо перепроверены статусы двух Actions runs на SHA `170f838ac583db4de0179450ac3b08c863864e7b`:

- [push CI — 37641089414](https://github.com/sanches16/tool-hunter/actions/runs/37641089414): completed/success.
- [pull_request CI — 37641100180](https://github.com/sanches16/tool-hunter/actions/runs/37641100180): completed/success.

Это сохранённые результаты конкретной ревизии. При подготовке настоящего описания приложение и Docker-тесты заново не запускались. Нельзя переносить этот PASS на будущие изменения или на main, где runtime-кода пока нет.

### 7.3 Почему PoC ещё не завершён

Функциональный health-срез существенно продвинут. Но PoC дополнительно проверяет запуск из чистого checkout, repository-only resumption, convergence, сохраняемые evidence, измерения процесса и final human decision. Эти obligations не закрываются зелёным CI.

## 8. Как мы разрабатываем

### 8.1 Последовательность

```text
Замысел → узкая SPEC → review владельца
→ plan/tasks/analyze → review активных ревизий
→ ограниченная реализация в ветке
→ независимые команды и CI
→ result + handoff с SHA
→ reviewer/convergence, optional critic
→ решение владельца о принятии и promotion
```

Git хранит намерение, код и решения. Spec Kit помогает формировать SDD-артефакты. Проверки выполняются вне LLM. Ветку и candidate SHA всегда указывают явно.

### 8.2 Роли

| Роль | Ответственность | Текущее соответствие инструментам |
| --- | --- | --- |
| Владелец | Цели, scope, human gates, финальное принятие/promotion | sanches16 |
| Architect | SPEC, план, границы, acceptance | Codex CLI в исходном PoC |
| Implementer | Изменения только в разрешённом срезе | Claude Code |
| Reviewer | Независимый diff/evidence review и convergence | Codex; для agent-loop предусмотрен ChatGPT reviewer |
| Critic | Дополнительный read-only анализ | Grok, optional |
| Deterministic verifier | Команды, тесты и CI outcomes | Shell/Node/GitHub Actions |

Cursor может выполнять роль в новом рабочем сеансе. Само открытие проекта в Cursor не меняет методику и не передаёт ему право approve/merge или live activation.

### 8.3 Восемь правил конституции v1.0.0

1. SPEC и plan до кода, review должен покрывать активные ревизии.
2. Изменять существующий канонический репозиторий reviewable patches; сохранять принятые артефакты.
3. Завершение подтверждать evidence, а не заявлением агента.
4. Проверки должны запускаться без AI и скрытого контекста.
5. Не расширять scope молча.
6. Merge/promotion требует явного human approval для конкретных изменений.
7. Секреты не попадают в Git, ответы и общие логи.
8. В PLATFORM-POC-001 не вводить custom orchestrator, очередь задач, agent DB, memory server или LLM gateway.

Документационная публикация в main прямо запрошена владельцем 11 октября. Это разрешение относится к описанию проекта; оно не является promotion approval для кода PoC.

### 8.4 Что считается хорошим handoff

Нужны iteration, branch, exact candidate SHA, changed files, результаты команд, реализованное, deviations, defects, blockers и next action. `NOT_RUN`, `PENDING`, `NOT_MEASURED` допустимы; подмена их на PASS или ноль недопустима.

Ревью привязано к exact SHA. Новый head или новая инструкция могут сделать старое решение неприменимым. Утверждение отдельного среза не равно приёмке всего продукта.

### 8.5 Issue и PR как каналы

[Issue #1](https://github.com/sanches16/tool-hunter/issues/1) содержит ручные handoff/review текущего PoC. [Issue #3](https://github.com/sanches16/tool-hunter/issues/3) содержит audit автоматизации. Для нового AGENT_LOOP_V1 control bus — top-level conversation comments активного PR. Issue #1 не должен запускать watcher.

Нужно читать действующий канал и самые новые сообщения. Старый текст Issue #1 нельзя использовать как замену новому протоколу автоматизации.

## 9. История и причины смены подхода

### 9.1 Какие GitHub-проекты взяли за основу и рассматривали

Стратегия была строить на существующих open-source проектах, чтобы использовать готовые SDD-артефакты и execution lanes. Источник решения — [PET_SDD_PLATFORM_COMPARISON_AND_POC_v0.1.md](reference/PET_SDD_PLATFORM_COMPARISON_AND_POC_v0.1.md), сохранённый без изменений как историческое обоснование.

| Проект | Как использовали в Tool Hunter | Почему |
| --- | --- | --- |
| [GitHub Spec Kit](https://github.com/github/spec-kit) | Выбранная и установленная основа SDD/process; pinned 1.0.12 | Constitution, SPEC, plan, tasks, analysis, workflows и gates; намерение хранится в Markdown/Git |
| [OpenAI Codex](https://github.com/openai/codex) | Установленная native execution lane architect/reviewer | GPT-сторона спецификации, планирования и независимого review |
| [Cline / кандидат Cline Teams](https://github.com/cline/cline) | Рассматривали для последующего отдельного эксперимента; обязательной частью baseline не стал | Единая среда/team runtime для уменьшения трения переключений |
| [Ruflo](https://github.com/ruvnet/ruflo) | Рассматривали как более тяжёлый вариант orchestration; отложили | Возможная координация workers/worktrees и shared memory при измеренной необходимости |

Дополняли baseline native Claude Code, optional Grok Build, Git и GitHub Actions. Взяли за основу именно Spec Kit + native CLIs; Cline/Ruflo были кандидатами, а не импортированным runtime. Исторические оценки возможностей и баллы comparison — judgement на момент выбора, не актуальный vendor benchmark.

### 9.2 Где именно застряли

Владелец описывает текущую трудность как «застряли с автоматизацией проверки шагов между Claude и GPT». По артефактам это два связанных узких места.

**Первое — автоматический контроль SDD-шагов.** Workflow должен был передавать SPEC/plan/tasks исполнителю, выполнять проверки, сохранять evidence и возвращать результат GPT-ревьюеру. Однако проверки неоднократно расходились с тем, что обещали документы: false positives, неправильное распределение задач между ролями, отсутствующие evidence producers, неполные CI/resume/RESULT records. В результате мы делали очередной ремонт workflow и снова останавливались на Gate 2B. Workflow 1.2.6 заморозили и перешли к ручным bounded incremental slices.

**Второе — автоматическая передача Claude → GPT → Claude.** После реализации среза Claude должен опубликовать HANDOFF с exact SHA, GPT независимо проверить diff/CI и вернуть bounded REVIEW_DECISION, а watcher — запустить только этот следующий разрешённый шаг. Именно для этого появился AGENT-LOOP-001. Здесь возникли проблемы reviewer identity и ownership, stale/duplicate comments, распознавания примеров как команд, headless permissions, разделения сети модели и инструментов, sandbox, Git publisher, актуальности SHA/STOP, locks и BLOCKED notification.

Детерминированные тесты и CI уже работают для health-среза. Незавершённой остаётся доказанная автоматизация всего перехода между агентами с безопасным запуском и сохранением результата. Kit 1.3.1 дошёл до READY_FOR_SMOKE в dry-run; полный реальный цикл ещё не подтверждён.

Цель — снять с владельца рутинную пересылку каждого сообщения и повторное объяснение контекста. При этом финальное принятие/promotion остаётся у человека. «Автоматическая проверка шага» не означает, что AI самостоятельно разрешает себе merge или новую продуктовую итерацию.

### 9.3 Хронология

| Этап | Что произошло | Вывод |
| --- | --- | --- |
| HTML v0.1.2 | Сформирован исходный каталог; обнаружены проблемы работы интерактивного файла в preview/на устройствах | Нужен полноценный клиент с сохранением исходных данных |
| 6 октября: web-прототип | Начат перенос в web; домен/API частично написаны; затем пауза | Черновики не считать принятым релизом |
| Master-spec 1.0.0-READY | Зафиксированы модель, стек, seed и Iteration 0–5 | Продукт имеет отдельную спецификацию |
| 7 октября: Mac setup | Репозиторий, CLI, Docker и Spec Kit подготовлены | `READY_FOR_PLATFORM_POC` — готовность среды |
| Spec + plan PoC | Gate #1 и Gate 2A приняты | Разрешены planning и последующие согласованные срезы |
| Workflow 1.2.0–1.2.6 | Повторные отказы из-за role boundaries, verifier/evidence gaps | Проверять реальное выполнение обещанного workflow |
| Run `44d3dbd2` | Workflow 1.2.6 заморожен; findings вынесены в backlog | Перейти к небольшим incremental slices |
| A–D3C1 | Реализованы skeleton, probe, tests, runtime, startup, CI, README | Появилась работающая основа без расширения продуктового scope |
| Следующий D3C2 | Запланировано доказательство fresh checkout | Закрыть независимость от локального контекста |
| AGENT-LOOP v1.1–1.3.1 | Исправлялись protocol, isolation, publisher, locks; 1.3.1 installed dry-run | Полный live smoke ещё нужен |

В run history семь запусков экспериментального workflow. Часть отказов относилась к проверяющим скриптам и сохранению evidence, а не к продуктовой реализации. Их нельзя автоматически считать семью repair cycles приложения. Числа и human ratings для результата PoC ещё нужно собрать по фактам.

В master-spec автоматизация Build Plane отложена до 2–3 успешных ручных итераций, а конституция запрещает custom orchestration в PoC. Позже отдельно появился AGENT-LOOP-001. Документы фиксируют эти события, но не оформляют автоматически waiver/amendment. Перед зависимым расширением нужно явно согласовать действующий governance и отделить transport experiment от product PoC.

## 10. Подробный бэклог

Статусы: **реализовано в candidate** — есть код и указанные evidence; **pending** — результата/приёмки нет; **поздняя итерация** — требование master-spec, ещё не разрешённое к реализации; **заморожено** — historical workflow debt.

Приоритеты P0/P1/P2 ниже — порядок, предлагаемый этим обзором, а не новая утверждённая SPEC. У задач продукта нет подтверждённых оценок в часах и дат завершения.

### 10.1 P0 — завершить и принять PLATFORM-POC-001

| ID обзора | Работа | Для чего | Критерий результата / зависимость | Статус |
| --- | --- | --- | --- | --- |
| POC-01 | D3C2 fresh checkout proof | Проверить, что README достаточен | Exact `170f838…`, новый clone, npm ci + пять checks, lifecycle 200→503→200→no response, same app, 0 source edits, cleanup | Задание утверждено; handoff не найден |
| POC-02 | Request-level evidence T009/T010 | Сохранить доказательства каждого observation | Opt-in JSONL, строгие восемь полей, 10/10/10, timing, app identity, versioned records | Pending; текущие assertions не равны retained evidence |
| POC-03 | T021 / RESULT | Собрать единый итог PoC | SHA, команды, версии, CI links, gaps, metrics, ratings, next action | Файл отсутствует в candidate |
| POC-04 | Resume implementer | Доказать восстановление контекста | Свежий read-only процесс: scope/status/evidence/gaps/next action | Pending |
| POC-05 | Resume reviewer | Независимо проверить понятность repo | Отдельный revision-linked report без исходного чата | Pending |
| POC-06 | Convergence | Сопоставить spec, tasks, код и evidence | Отчёт без неучтённых gaps или traceable corrective work | Pending |
| POC-07 | Optional critic | Найти дополнительные проблемы | Read-only отчёт либо явное not performed | Pending / optional |
| POC-08 | Human metrics | Оценить процесс, а не только endpoint | Реальные counts и шесть ratings 1–5 | Pending |
| POC-09 | Final acceptance и promotion | Завершить эксперимент явным решением | Владелец оценивает complete RESULT и exact revision | Pending; PR #2 открыт |

Последнее разрешённое задание — POC-01. POC-02–09 описывают оставшиеся obligations и требуют очередного bounded direction; это не инструкция немедленно выполнить весь список.

### 10.2 Карта T001–T021

| Tasks | Содержание | Реальное положение |
| --- | --- | --- |
| T001–T005 | package/scripts, TS, lint, ignore, skeleton | Реализованы incremental A |
| T006 | Shared HTTP assertions | Нужная часть реализована C |
| T007 | Silent listener | Реализован D2C1 с rework |
| T008 | Test Compose fixtures | Реализованы через D2B–D2C3 |
| T009 | Real 10/10/10 + opt-in evidence writer | Поведение реализовано D2B; JSONL retention отложен |
| T010 | Fault matrix + socket cleanup + evidence | Runtime faults реализованы; retained observation evidence pending |
| T011 | Focused probe failures / false-full-health control | Реализован C |
| T012–T014 | Configuration, DB probe, route | Реализованы B |
| T015–T017 | Dockerfile, Compose, env example | Реализованы D1 |
| T018 | Runtime README | Реализован D2A; обновлён D3C1 |
| T019 | verify:startup | Реализован D3A |
| T020 | CI push + PR | Реализован D3B1; PR path доказан D3B2; оба зелёные на D3C1 |
| T021 | Result structure | Pending |

Исторический tasks.md содержит все 21 checkbox unchecked. Это frozen planning artifact. Из него нельзя заключить «кода нет» или молча поставить всё done. Состояние определяется кодом, commits, review и acceptance evidence по каждой части требования.

### 10.3 Отдельный бэклог AGENT-LOOP-001

| ID обзора | Работа | Что должно быть доказано |
| --- | --- | --- |
| LOOP-01 | Подтвердить reviewer identity | Реальный author/login, при совпадении с operator — app slug; ownership primary/fallback |
| LOOP-02 | Выполнить auth prerequisite | Token file подготовлен без вывода значения; doctor и sandbox-compatible auth |
| LOOP-03 | Защитить canonical branch | Protection согласно checklist; lease не заменяет branch protection |
| LOOP-04 | Throwaway protocol test | Valid bounded decision принят; fence/duplicates/stranger/fork/Issue #1 не запускают работу |
| LOOP-05 | Реальная модель в sandbox | Claude reaches inference broker; tool network denied; реальный профиль applied |
| LOOP-06 | Publisher boundary | Изменённые git metadata/hook отклонены; moved/closed PR и STOP отменяют publish |
| LOOP-07 | Первый live cycle | Только новый разрешённый decision, один descendant CAS push, один HANDOFF, SHA dedupe |
| LOOP-08 | Уведомление/пауза/rollback | BLOCKED не превращается в новую работу; pause видна doctor; rollback проверен |
| LOOP-09 | Governance alignment | Явно документировать scope transport experiment и ограничения PoC/master-spec |

Kit 1.3.1 установлен и готов к smoke согласно audit. Этот список не является разрешением выставить `dry_run=false` или выполнить live calls.

### 10.4 Замороженный workflow debt

| ID источника | Severity | Проблема | Текущая политика |
| --- | --- | --- | --- |
| B1 | HIGH | safety-review требует tracked `.env.example` до staging | Заморожено; не блокирует incremental implementation |
| B2 | HIGH | Grok not performed нельзя честно выразить числовой metric | Заморожено; фиксировать nonparticipation отдельно |
| B3 | MEDIUM | verification-enforce outcome не записывается в RESULT | Заморожено; не считать print сохранённым evidence |
| B4 | MEDIUM | Final gate record не связан с RESULT | Заморожено; нужен явный revision-linked итог |

Источник: [PLATFORM-POC-001-BACKLOG.md на candidate](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/docs/poc/PLATFORM-POC-001-BACKLOG.md). Ремонт всего workflow не является обязательным следующим шагом.

### 10.5 Продуктовый бэклог по master-spec

| Итерация | Работа | Ценность и критерии | Статус |
| --- | --- | --- | --- |
| 0 | Drizzle + SQL migrations | Foundation schema создаётся с пустой DB | После принятия PoC |
| 0 | Workspace / Item / ItemImage / необходимые ItemPriceTarget | Полная seed-модель без SearchRun/Listing | После принятия PoC |
| 0 | Canonical metadata + 15 images | Exactly 15, stable seed_key, original hashes | Metadata описаны; assets ещё не импортированы в canonical repo |
| 0 | Idempotent seed | Второй запуск не дублирует items/media и сохраняет priority/order | Pending |
| 0 | ImageStorage + persistent volume | Изображения принадлежат приложению и переживают recreation | Pending |
| 0 | Server-rendered verification page | 15 читаемых карточек без зависимости от hydration | Pending |
| 0 | DB/media backup + restore-test | После восстановления совпадают count/keys/hashes/order/priority | Pending |
| 0 | VERSION / CHANGELOG / RESULT-ITER0-FINAL | Реальный отчёт и reproducible commands | Pending |
| 1 | Catalog Core, фото/пиктограммы | Полноценный каталог iPhone/desktop | Pending |
| 1 | Stars и manual controls | Сохранение порядка; «В начало», ↑, ↓; priority regression tests | Pending |
| 1 и отдельный access-slice | Проверка iPhone/Tailscale/PWA | Реальный телефон; согласовать manifest/installability и private access | Pending; точный split ещё нужен |
| 2 | CRUD + lifecycle | Create/edit, intent/retention, archive/restore/trash/purchased | Pending |
| 2 | Image upload | MIME/size/EXIF/hash, понятные ошибки, storage persistence | Pending |
| 3 | Search domain | SearchRun/Listing/ItemListing/RejectedListing/PriceSnapshot | Pending |
| 3 | Versioned JSON import/export задания | Validation, dedupe, idempotency, explicit errors | Pending |
| 3 | Pricing/history/scoring | Три ценовых уровня, stale reference, детерминированные labels и risk flag | Pending |
| 4 | External/local browser agent | ≥20 inspected cards и ≤5 релевантных результатов; server без Avito session | Pending |
| 5 | Telegram notifications | SUPER, buy-now crossing, failed SearchRun | Поздняя итерация |
| Позже | Mini App / новые категории и marketplace | Те же API/domain, без дублирования | Вне MVP core |
| После стабильной 1 | VPS/Caddy/domain/OAuth/off-site backup | По отдельной deployment/security спецификации | Отложено |

## 11. Дорожная карта и критерии готовности

### 11.1 Ближайший разрешённый шаг

В [последнем review Issue #1](https://github.com/sanches16/tool-hunter/issues/1#issuecomment-6040826429) разрешён D3C2: новый временный clone exact `170f838…`, процедура README, полный documented lifecycle и пять проверок, ноль source edits, удаление только своих временных ресурсов, safe handoff и STOP. Не начинать RESULT, resume, convergence, Grok или merge автоматически.

Текущая задача 11 октября — описание и публикация документации. Она не выполняет D3C2 и не заменяет его evidence.

### 11.2 Когда принять PoC

Нужны рабочий health-срез, оба CI paths, fresh-checkout proof, безопасные revision-linked records, independent resume/review, convergence, optional critic или explicit skip, реальные process metrics и final human decision. После этого владелец решает, подходит ли процесс и можно ли переходить к `SPEC-ITER0-FINAL`.

### 11.3 Что означает готовая продуктовая Iteration 0

Она существенно шире текущего PoC: migrations, canonical 15 items и photos, idempotent seed, persistent DB/media, verification page, backup/restore и `RESULT-ITER0-FINAL.md`.

Пример acceptance: первая seed даёт 15 Items; вторая — те же 15 без дублей; у каждого есть primary image и SHA; app recreation сохраняет DB/media; isolated restore возвращает seed keys, image hashes, приоритет и порядок. SearchRun, Listing, full UI, auth/OAuth, Avito, Telegram, Playwright, VPS и agent automation в Iteration 0 не входят.

### 11.4 Качество продукта после Catalog Core

Release должен выявлять потерю canonical items/photos, blank thumbnails, некликабельные stars, сломанное «В начало», потерю manual order, изменение priority algorithm и миграцию с потерей данных. С Iteration 1 предусматриваются Playwright, mobile viewport и screenshot regression. Для текущего PoC такие UI tests не нужны.

### 11.5 Метрики процесса

В RESULT PoC должны быть версии участвующих инструментов; counts ручных пересылок, повторного объяснения контекста, human gates, repair cycles, convergence gaps, новых critic findings, scope deviations, broken SDD artifacts; elapsed time и CI outcome. Владелец выставляет шесть ratings 1–5: сложность настройки, трение переключения агентов, ясность артефактов, доверие review, качество resume и желание повторно использовать процесс.

Все значения заполняются наблюдениями. «Не измерено» честнее вымышленного нуля; critic not performed нельзя превращать в «0 найденных проблем» без объяснения.

## 12. Канонический каталог

Данные ниже — исходный seed из master-spec, **не актуальные рыночные котировки**. `—` означает reference_price отсутствует. Порядок 0–14 — seed manual_order.

| Порядок | seed_key | Бренд / модель и назначение | ★ | Reference ₽ | Пиктограмма |
| ---: | --- | --- | ---: | ---: | --- |
| 0 | mw-2521-20 | Milwaukee 2521-20 — M12 FUEL компактная циркулярная пила | 3 | 17 900 | 🔴 |
| 1 | mw-2831-20 | Milwaukee 2831-20 — M18 FUEL погружная пила по шине | 5 | — | 🔴 |
| 2 | mw-2833-20 | Milwaukee 2833-20 — M18 FUEL циркулярная пила 165 мм | 4 | — | 🔴 |
| 3 | mw-2834-20 | Milwaukee 2834-20 — M18 FUEL циркулярная пила 184 мм | 4 | — | 🔴 |
| 4 | dewalt-dcs579nt | DeWalt DCS579NT — FLEXVOLT 54V дисковая пила | 3 | 33 500 | 🟡 |
| 5 | mw-m18-xc5 | Milwaukee M18 XC5.0 — M18 REDLITHIUM аккумулятор 5 Ah | 4 | 5 700 | 🔋 |
| 6 | dewalt-dcb118 | DeWalt DCB118 — быстрое зарядное устройство | 1 | 4 800 | 🔋 |
| 7 | mw-2505 | Milwaukee 2505 — M12 FUEL Installation Driver 4-в-1 | 5 | 19 000 | 🔴 |
| 8 | daewoo-davc-1621li | Daewoo DAVC 1621Li SET — аккумуляторный строительный пылесос | 3 | 14 500 | 🟠 |
| 9 | dewalt-dcs438b | DeWalt DCS438B — компактная отрезная машина | 2 | 14 299 | 🟡 |
| 10 | mw-m12-ho5 | Milwaukee 48-11-2450 — M12 HIGH OUTPUT аккумулятор 5 Ah | 4 | 6 400 | 🔋 |
| 11 | mw-2522-20 | Milwaukee 2522-20 — M12 FUEL компактная отрезная машина | 4 | 13 500 | 🔴 |
| 12 | mw-0970-20 | Milwaukee 0970-20 — M18 FUEL PACKOUT пылесос | 4 | 26 990 | 🟠 |
| 13 | diablo-dou5spc | Diablo DOU5SPC — набор полотен для реноватора, 5 шт. | 1 | 5 750 | ⚙️ |
| 14 | mw-blhsb-0 | Milwaukee BLHSB-0 — M18 компактная воздуходувка | 2 | 14 990 | 🟠 |

У 2505 seed notes различают tool-only около 19 000 ₽ и kit около 25 000 ₽; это всё ещё одна модель. Фото должны переноситься из исходных assets, а не заменяться на вновь найденные.

В раннем прототипе несколько IDs названы иначе: `dw-dcs579nt`, `dw-dcb118`, `dw-dcs438b`, `daewoo-davc1621li`. При переносе потребуется явная mapping table к seed_key master-spec и сопоставление фото по содержимому/hash.

## 13. Риски и открытые решения

| Вопрос | Почему важен | Как закрывать |
| --- | --- | --- |
| Неполный финальный PoC evidence | Working code и accepted process — разные результаты | D3C2, records, resume, convergence, metrics, human decision |
| Runtime не в main | Новый разработчик может попытаться запускать отсутствующий package.json | Явно читать branch/SHA map и runtime README candidate |
| Старые labels draft/pending и unchecked tasks | Frozen artifacts расходятся с последующей историей | Сопоставлять gate records и Issue/PR chronology, не переписывать history |
| Automation scope против исходных ограничений | Agent-loop появился раньше полной приёмки продукта | Явно согласовать governance до дальнейшего расширения |
| Reviewer/operator могут иметь один GitHub login | Author allowlist недостаточен для отличения действий | Реальный app attribution и ownership protocol |
| Main пока unprotected | Checklist live loop ещё не закрыт | Отдельно настроить protection, без предположения о наличии |
| Исторический prototype и master-spec отличаются | Риск переноса D1/старых статусов/IDs в новый продукт | Controlled migration и comparison report |
| Product assets пока локальны | Fresh repo недостаточен для product seed | Отдельный asset import, hashes, metadata mapping и review |
| Сортировка между группами и concurrent edits | Возможна потеря ручного порядка | Уточнение Catalog Core contract и meaningful tests |
| Missing/stale price targets и seller-risk data | Score может стать недостоверным | Явные deterministic fallback rules и source/freshness UI |
| Raw agent responses | Могут содержать лишние данные | Schema, retention/redaction policy, безопасный аудит |
| Реальный iPhone и приватный доступ | Desktop build не доказывает mobile usability/installability | Device checks, отдельный access/PWA slice |
| Развитие процесса вместо продукта | Можно снова уйти в ремонт workflow | Узкие acceptance-driven slices и измерение friction |

Нет зафиксированных сроков, бюджета эксплуатации, текущей рыночной стоимости каталога или результата будущих smoke tests. Настоящий документ их не выдумывает.

## 14. Источники и обновление описания

### 14.1 Приоритет источников

Для выполнения работы нужно учитывать прямое актуальное решение владельца, конституцию и зафиксированные governance corrections, активную reviewed SPEC/plan, самые новые revision-linked decisions и реальные код/evidence. Этот обзор помогает найти их; он не самоустанавливает новые права.

Master-spec — продуктовый reference для этапа **после принятия PoC**. Active PoC имеет более узкие границы. Исходный архив явно задаёт последовательность Mac setup → PLATFORM-POC-001 → review результата → Tool Hunter Iteration 0.

### 14.2 Сохранённые первичные документы

- [Исходная TOOL_HUNTER_MASTER_SPEC_v1.0_READY.md](reference/TOOL_HUNTER_MASTER_SPEC_v1.0_READY.md), импортирована в этот пакет без изменений: SHA-256 `0bc307b0ab9df2ddb71d89fe07b8cebef74426e4cb55d1f5e66e8d56232b9d92`, 41 627 bytes. Оригинальная version — 1.0.0-READY; импорт 11 октября не является её amendment или implementation approval.
- [Исходное сравнение платформ PET_SDD_PLATFORM_COMPARISON_AND_POC_v0.1.md](reference/PET_SDD_PLATFORM_COMPARISON_AND_POC_v0.1.md): исторический выбор Spec Kit/native lanes и отложенных Cline/Ruflo.
- [Конституция 1.0.0](../.specify/memory/constitution.md).
- [PLATFORM-POC-001 intent](poc/PLATFORM-POC-001.md).
- [MAC_SETUP_RESULT](poc/MAC_SETUP_RESULT.md): историческая готовность среды, не текущая диагностика инструментов.
- [Spec на exact candidate](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/specs/001-foundation-health/spec.md).
- [Plan на exact candidate](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/specs/001-foundation-health/plan.md).
- [Tasks на exact candidate](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/specs/001-foundation-health/tasks.md).
- [Run history](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/docs/poc/PLATFORM-POC-001-RUN-HISTORY.md).
- [Runtime README](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/README.md).
- [Issue #1 handoff/review](https://github.com/sanches16/tool-hunter/issues/1), [PR #2](https://github.com/sanches16/tool-hunter/pull/2), [Issue #3 automation audit](https://github.com/sanches16/tool-hunter/issues/3).

### 14.3 Исторические локальные источники

Дополнительно прочитаны original HTML v0.1.2, его extracted seed/image map, pause handoff от 6 октября, код раннего web-прототипа, доступные сообщения проекта и kit 1.3.1 CHANGELOG/VALIDATION/MIGRATION_CHECKLIST. Они использованы для provenance и различения версий; исходники старого приложения и automation kit этой публикацией не импортированы.

Исходный HTML и его baseline-копия совпадают: SHA-256 `7bb649c11351f7175e18751acf555df3a919d472c03a9d46488711bb81e9b0df`. Extracted `seed.json`: `98927fda23a6535a32714231c1221f7a42cd174990a1f7f7bdbb9b8be401f7d6`. Эти hashes помогают проверить будущий перенос, но не заменяют сам asset bundle.

### 14.4 Как поддерживать описание

После изменения head, принятия среза или final gate обновить оба описания, сохраняя различие «код», «evidence», «принятие» и «promotion». Указывать дату, exact SHA и ссылки на новые records. Старые milestones сохранять как историю; не приписывать новый PASS старой проверке. Продуктовые изменения оформлять новой SPEC/ADR/CHANGELOG согласно master-spec.
