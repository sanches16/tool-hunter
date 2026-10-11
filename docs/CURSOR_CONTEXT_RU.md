# Tool Hunter — контекст проекта и инструкция для Cursor

**Версия:** 1.0.0 · **Snapshot:** 2026-10-11, Europe/Moscow.

Этот документ предназначен для нового AI-сеанса в Cursor: понять продукт, мультиагентную платформу, текущую ревизию, правила работы, бэклог и следующий разрешённый шаг. Это context/handoff, не build packet. Человеческое объяснение: [PROJECT_OVERVIEW_RU.md](PROJECT_OVERVIEW_RU.md).

## 1. Краткий обязательный контекст

```yaml
project: Tool Hunter
canonical_repository: sanches16/tool-hunter
repository_url: https://github.com/sanches16/tool-hunter
visibility: private
default_branch: main
snapshot_date: 2026-10-11
timezone: Europe/Moscow
product_goal: private catalog, purchases, marketplace search and price history
platform_goal: reusable multi-agent SDD development platform for pet projects
first_platform_test_project: Tool Hunter
active_experiment: PLATFORM-POC-001
active_runtime_branch: poc/platform-poc-001-incremental
reviewed_runtime_sha: 170f838ac583db4de0179450ac3b08c863864e7b
last_approved_slice: D3C1
next_recorded_slice: D3C2 repository-only fresh checkout proof
product_iteration_0: not started in canonical repository
final_poc_acceptance: not found in checked records
automation_track: AGENT-LOOP-001
latest_automation_audit: kit 1.3.1 READY_FOR_SMOKE, dry-run
live_agent_loop: not proven
main_before_this_documentation_publication: 0dbbd728643e1025100cdf29d07864be60fb6642
```

Это исторический snapshot. До действий перечитай текущие refs, PR и decisions. Новые evidence могут изменить состояние. Не выдавай сохранённый snapshot за live telemetry.

**Текущий bottleneck:** автоматизация контроля и handoff между Claude и GPT. Health runtime и CI работают; полная цепочка «Claude HANDOFF → GPT review exact SHA → bounded decision → безопасный запуск Claude → новый HANDOFF» ещё не принята. Владелец прямо подтвердил 11 октября, что в рамках Tool Hunter строится мультиагентная платформа разработки.

## 2. Источники, authority и разрешения

### 2.1 Что читать

1. Актуальный запрос владельца и applicable repository instructions.
2. `.specify/memory/constitution.md`, version 1.0.0, и реальные approved amendments, если появились.
3. `docs/poc/PLATFORM-POC-001.md`: active PoC intent и exclusions.
4. На reviewed runtime revision: `specs/001-foundation-health/spec.md`, `plan.md`, contracts, tasks и review/gate records.
5. Самые новые comments в [Issue #1](https://github.com/sanches16/tool-hunter/issues/1), [PR #2](https://github.com/sanches16/tool-hunter/pull/2) и применимый audit [Issue #3](https://github.com/sanches16/tool-hunter/issues/3).
6. Реальный code/diff/CI на exact SHA.
7. [Master-spec](reference/TOOL_HUNTER_MASTER_SPEC_v1.0_READY.md) как product reference **после принятия PoC**.
8. [Platform comparison](reference/PET_SDD_PLATFORM_COMPARISON_AND_POC_v0.1.md) как историческое обоснование стека.

Если sources конфликтуют, выяви конкретный конфликт и проверь актуальные explicit human decisions/governance records. Этот context не создаёт waiver. Не используй старый draft label как единственный статус: spec и plan сохраняют planning labels, а последующие gate records и incremental decisions фиксируют развитие.

### 2.2 Восемь правил

- Reviewed SPEC/plan before code; approvals должны покрывать активные revisions.
- Patch existing canonical repo; не реконструировать принятый проект по памяти.
- Completion = reproducible evidence mapped to acceptance, а не agent claim.
- Required checks запускаются без LLM.
- Scope не расширяется молча.
- Human promotion gate; implement permission и green CI не равны merge approval.
- Secrets не входят в Git/общие логи/HTTP diagnostics.
- В PLATFORM-POC-001 запрещены custom orchestration/task queue/agent DB/memory server/LLM gateway и Cline/Ruflo.

Исключения и amendments должны иметь реальные human-reviewed records. Не переписывай конституцию, approved SPEC/plan/gates или frozen workflow для удобства очередной задачи.

### 2.3 Что разрешает этот документ

Сам по себе — ничего реализовывать, запускать или сливать. Он объясняет контекст. Конкретное действие выполняется по текущему пользовательскому запросу/active bounded direction. Не задавай повторный permission question, если необходимая операция уже явно разрешена и её scope подтверждён.

Публикация этой документации в main отдельно запрошена владельцем 11 октября. Она не разрешает merge PR #2, live activation, product Iteration 0 или запуск старого end-to-end workflow.

## 3. Ветки и реальное состояние

| Ref | SHA на snapshot | Что есть |
| --- | --- | --- |
| main до публикации docs | `0dbbd728643e1025100cdf29d07864be60fb6642` | Setup, constitution, Spec Kit, PoC intent; runtime отсутствует |
| poc/platform-poc-001 | `c372a9434f9142bfc075ac8d6df0d4f3aa7a726c` | Planning + frozen workflow 1.2.6 |
| poc/platform-poc-001-incremental | `170f838ac583db4de0179450ac3b08c863864e7b` | Next.js health runtime + Docker + tests + CI + runtime README |
| docs/agent-loop-smoke-v13 | `0dbbd728643e1025100cdf29d07864be60fb6642` | На snapshot без smoke changes |

PR #2: OPEN/non-draft/unmerged, head incremental, base `poc/platform-poc-001`, не main. Auto-merge не включён. Branch API показывает main unprotected на дату сверки; не объявляй protections существующими.

После docs publication main содержит два описания, исходные reference docs, навигационный README и Cursor bootstrap rule. Это не runtime promotion. Не запускай `npm ci` в main с предположением, что там уже существует приложение.

В candidate tree отсутствуют RESULT PoC, `docs/poc/evidence/<sha>/`, RESUME_IMPLEMENTER, RESUME_REVIEWER, CONVERGE и final acceptance. Latest Issue #1 decision = APPROVE D3C1 + direction D3C2. Completed D3C2 handoff в проверенных comments не найден.

## 4. Как начать новый сеанс

### 4.1 Read-only preflight

```bash
git status --short --branch
git remote -v
git branch -vv
git log -8 --oneline
```

Определи current branch, worktree cleanliness, canonical remote и local/remote SHA. Не discard пользовательские changes. Если работа требует актуальных GitHub данных, прочитай refs/comments/checks через доступный connector или стандартные инструменты; при разрешённом network refresh используй fetch. Не трактуй старый `origin/...` как доказательство текущего remote head.

На main используй immutable links ниже для ознакомления с runtime. Для работы с кодом выбери уже существующий подходящий checkout/worktree и правильную ветку согласно действующему заданию. Не переключай чужой активный checkout и не merge runtime только ради наличия файлов.

### 4.2 Перед реализацией восстанови пять пунктов

```text
APPROVED_SCOPE: exact bounded instruction and reviewed inputs
CURRENT_STATUS: branch / SHA / last accepted slice
EVIDENCE: commands, outcomes, URLs, tested revision
GAPS: unfinished criteria, conflicts and missing prerequisites
NEXT_ACTION: action actually authorized now
```

Если восстановление невозможно, зафиксируй конкретный пробел и продолжай независимый read-only анализ. Не заполняй отсутствующий approval или metric своим предположением.

### 4.3 Где найти runtime-артефакты

- [Runtime README](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/README.md).
- [Feature spec](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/specs/001-foundation-health/spec.md).
- [Plan](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/specs/001-foundation-health/plan.md).
- [Tasks](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/specs/001-foundation-health/tasks.md).
- [Runtime contract](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/specs/001-foundation-health/contracts/runtime.md).
- [HTTP contract](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/specs/001-foundation-health/contracts/health.openapi.yaml).
- [Run history](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/docs/poc/PLATFORM-POC-001-RUN-HISTORY.md).
- [Frozen backlog](https://github.com/sanches16/tool-hunter/blob/170f838ac583db4de0179450ac3b08c863864e7b/docs/poc/PLATFORM-POC-001-BACKLOG.md).

## 5. Текущий PoC: архитектура и контракт

### 5.1 Scope

Один минимальный Next.js App Router project, Node runtime, TypeScript strict, PostgreSQL 17, `pg`, production Docker image, app/db Compose, один `/api/health`, независимые проверки и CI. Не требуются ORM, доменные таблицы, seed, migrations, product UI или deployment.

PoC exclusions: canonical catalog/photos, Drizzle domain schema, auth, PWA, Avito/SearchRun/Listing, backup/restore, Telegram, VPS/Caddy, Cline/Ruflo, custom orchestration, auto repair и auto-merge.

### 5.2 Exact package baseline

Из package.json на `170f838…`, исторические pins — не рекомендации latest:

| Компонент | Значение |
| --- | --- |
| Node engines | `>=24 <25` |
| Next.js | `16.4.0` |
| React / React DOM | `19.3.0` |
| pg | `8.23.1` |
| TypeScript | `6.0.3` |
| ESLint | `9.39.5` |
| eslint-config-next | `16.4.0` |
| PostgreSQL | 17, image pinned digest |
| Package manager | npm + committed package-lock.json |

Node/PostgreSQL image references бери из actual Dockerfile/Compose, не выбирай новые digests по памяти. Не обновляй зависимости в документационном или evidence-only срезе.

### 5.3 Карта файлов

```text
src/app/layout.tsx                 minimal shell
src/app/page.tsx                   static verification/liveness shell
src/app/api/health/route.ts         GET handler, fixed responses, no-store
src/lib/database-health.ts         config snapshot, deadline, pg probe, cleanup
tests/helpers/health-assertions.mjs exact body/header/status/timing assertions
tests/integration/health.test.mjs   focused + real Docker scenarios
tests/fixtures/stalled-postgres.mjs silent TCP dependency, active-socket control
tests/compose.test.yaml            isolated fault/lifecycle fixture profiles
scripts/verify-startup.mjs         isolated production startup proof
Dockerfile                        multi-stage, pinned Node 24
compose.yaml                      app/db, localhost HTTP, private database
.env.example                      empty password placeholder
.github/workflows/ci.yml           push and pull_request, read-only permissions
specs/001-foundation-health/       intent/contracts/reviews
docs/poc/                         experiment/setup/history/backlog
```

### 5.4 Health invariants

- Handler starts one monotonic deadline before config validation.
- Fresh short-lived client and `SELECT 1 AS ok` on every request.
- Total `PROBE_BUDGET_MS=4000`; внешнее требование ≤5000 ms.
- No cached prior health, fallback database или environment bypass.
- Healthy: 200 + ровно `{status:ok,application:ok,database:ok}`.
- Invalid config/connect/auth/query/result/timeout: 503 + ровно `{status:degraded,application:ok,database:unavailable}`.
- `Cache-Control: no-store`, JSON content type, no extra properties.
- Stopped app: no HTTP response, не искусственный 503.
- Late success не меняет уже выбранный unavailable outcome.
- Failed/timed-out transport уничтожается; graceful healthy close ограничен, не задерживает HTTP.
- Test-client injection — только code-level boundary; production использует реальный pg.
- После DB recovery тот же app container/process возвращает 200 без restart.
- Health HTTP/logs не показывают password, host/user/database values, connection strings или raw driver errors.

### 5.5 Конфигурация и runtime

Обязательны POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD. Port: digits only, 1–65535. Missing/empty/invalid = unavailable, без defaults. Production Compose задаёт db:5432, публикует app только 127.0.0.1:3000 и не публикует DB port. `.env` untracked/ignored; `.env.example` содержит empty password.

Persistent db-data использует credentials первоначальной инициализации. Изменение `.env` не меняет уже созданную PostgreSQL role. Не regenerate password поверх пользовательского `.env`. Не выполнять `docker compose config` с реальными values в общие outputs.

Ordinary `docker compose down` сохраняет volume. `down -v` удаляет данные; допустимо только для явно принадлежащего проверке disposable project, не для пользовательской DB. Cleanup ограничивается ресурсами текущего test run.

## 6. Проверки и evidence

### 6.1 Команды на runtime branch

```bash
npm ci
npm run lint
npm run typecheck
npm run build
npm test
npm run verify:startup
```

Для разрешённого runtime change нужны checks active spec. Build не требует DB или secrets; typecheck независим от предыдущего build. npm test и verify:startup требуют running Docker/Compose и уникальные isolated projects с ephemeral credentials. Missing Docker = FAIL.

Для описаний/ссылок проверяй Markdown, source accuracy, diff scope, отсутствие secrets и публикацию. Не объявляй runtime tests пройденными только потому, что changed files — docs; сохраняй actual NOT_RUN и ссылки на исторические CI.

### 6.2 Подтверждённые CI

На exact `170f838ac583db4de0179450ac3b08c863864e7b` GitHub API независимо подтвердил completed/success:

- [Push run 37641089414](https://github.com/sanches16/tool-hunter/actions/runs/37641089414).
- [PR run 37641100180](https://github.com/sanches16/tool-hunter/actions/runs/37641100180).

Не путай head SHA и synthetic merge SHA: каждый новый proposed-change run проверяй отдельно. Отсутствующий run или prerequisite не является PASS.

### 6.3 Existing coverage

10 healthy → DB stop → 10 unavailable → DB start/readiness → 10 recovered; exact bodies/no-store/timing и unchanged app identity. Silent listener: 5 unavailable requests, active sockets возвращаются к baseline ≤1000 ms после каждого response. Configuration variants, wrong password, cold refused destination. Focused connect/query rejection/hang, unexpected result, late success, resource cleanup и false-full-health assertion control.

### 6.4 Недостающий retained observation evidence

T009/T010 требуют opt-in writer под `POC_TEST_EVIDENCE_PATH`, JSON Lines с **ровно восемью** ключами:

```text
phase
index
http_status
body
elapsed_ms
scenario
app_container_id
app_started_at
```

Main phases: `healthy`, `database-loss`, `database-recovery`, по 10 records. Index integer ≥0; exact 200/503; body ровно три поля; elapsed 0..5000 monotonic. Container ID/StartedAt nonempty и одинаковы во всех 30 main records; для других scenarios identity keys остаются present string/null. Без opt-in variable writer ничего не пишет. Transport failure/invalid body никогда не сериализуются как passing observation. Versioned sanitized evidence и mapping в RESULT ещё pending.

## 7. Current task status и разрешённый next step

### 7.1 Карта реализации

| Task | Состояние на candidate |
| --- | --- |
| T001–T005 | Skeleton/config реализованы A |
| T006 | Needed assertions реализованы C |
| T007 | Silent fixture реализована D2C1 + rework |
| T008 | Fixture variants реализованы D2B–D2C3 |
| T009 | 10/10/10 implemented; retained JSONL pending |
| T010 | Fault/socket matrix implemented; retained JSONL pending |
| T011 | Focused tests implemented C |
| T012–T014 | Configuration/probe/route implemented B |
| T015–T017 | Docker/Compose/env implemented D1 |
| T018 | README D2A + current-state sync D3C1 |
| T019 | Startup verifier D3A |
| T020 | CI D3B1 + PR path D3B2, обе checks на D3C1 |
| T021 | RESULT structure absent / pending |

Все 21 checkboxes исторического tasks.md остаются unchecked. Не ставь done без criterion evidence и не считай это доказательством отсутствия реализации.

### 7.2 Последнее recorded direction: D3C2

Источник: [review comment 6040826429](https://github.com/sanches16/tool-hunter/issues/1#issuecomment-6040826429). Если новое пользовательское задание действительно продолжает эту итерацию и нет более свежего superseding decision:

1. Brand-new temporary clone canonical repository outside current working tree.
2. Detach exact `170f838ac583db4de0179450ac3b08c863864e7b`.
3. Только README этого clone; не копировать node_modules, .env, runtime state или файлы developer checkout.
4. Допустим ignored `.env` по инструкции, private generated password, confirmation ignored/untracked.
5. npm ci; production Compose startup; exact 200; record app ID/StartedAt; stop DB; exact 503 ≤5000 ms; same app running; start DB + bounded readiness; exact 200 + same ID/StartedAt; stop app → no response.
6. Все пять documented verification commands PASS.
7. Git tracked modifications = 0.
8. Cleanup only owned stack, disposable volume, image, .env and clone; residue counts zero.
9. Safe evidence + handoff, changed files `none`, STOP.

Если README требует source edit/undocumented compensation, BLOCKED после cleanup; отдельный documentation defect, без silent repair во время proof.

Не запускать D3C2 при простом запросе «объясни проект». Не начинать T021, resume, convergence, critic, merge или product Iteration 0 автоматически после него.

### 7.3 Остальные PoC obligations

После следующих bounded decisions: observation evidence; complete RESULT; fresh read-only implementer/reviewer resume reports; convergence; optional critic/not performed; actual counts и шесть human ratings; final decision и отдельно authorized promotion. PR #2 merge не переносит код прямо в main из-за его base branch.

### 7.4 Frozen workflow

Workflow `platform-poc-001` v1.2.6 заморожен после Gate 2B reject run `44d3dbd2`. Не restart/rewrite его ради next slice. B1 tracked-env/staging mismatch, B2 Grok nonparticipation metric, B3 verification-enforce retention, B4 final-gate/RESULT link остаются historical debt и не блокируют incremental implementation.

## 8. Мультиагентная платформа и история затруднений

### 8.1 Цель платформы

Reusable development framework for pet projects: preserve intent, разные сильные модели по ролям, tests вне LLM, минимальная ручная пересылка, низкая потеря контекста, human control и resumption из repo. Tool Hunter — первый real workload.

Обсуждение продукта может оставаться в ChatGPT, но accepted intent переводится в Git artifacts. Native CLI не обязан совпадать с моделью, использованной в обсуждении. Abstract repository roles: architect, implementer, reviewer, critic; vendor names — конкретное текущее mapping.

### 8.2 Upstream foundation

| Источник | Реальное использование |
| --- | --- |
| [github/spec-kit](https://github.com/github/spec-kit) | Selected SDD/process core, pinned 1.0.12, integrated Codex/Claude/Grok |
| [openai/codex](https://github.com/openai/codex) | Native architect/reviewer lane, установлен согласно setup record |
| [cline/cline](https://github.com/cline/cline), Cline Teams candidate | Evaluated/deferred, не mandatory runtime |
| [ruvnet/ruflo](https://github.com/ruvnet/ruflo) | Evaluated/deferred heavier orchestration candidate |

Claude Code = implementer; Grok Build = optional critic; Git/Actions = artifacts и verifier. Comparison scores относятся к историческому архитектурному выбору, не являются benchmark. Не install/migrate Cline/Ruflo по одному упоминанию в roadmap.

### 8.3 Почему «застряли между Claude и GPT»

1. Spec Kit end-to-end workflow должен был передавать задачу, проверять выполнение, фиксировать evidence и возвращать review. Несколько run отклонены: role-boundary mismatch, false-positive guards и обещания evidence, которых скрипты не выполняли. После седьмого run workflow frozen, работа incremental.
2. Ручные slices дали работающий runtime и CI, но владелец продолжал пересылать handoff/review между Claude и GPT.
3. AGENT-LOOP-001 должен автоматизировать именно этот transport и запуск bounded next iteration. Версии kit исправлялись из-за identities, headless permissions, parser ambiguity, stale refs/stops, network/filesystem isolation, Git hooks/config, lock semantics и notifications.
4. Latest kit 1.3.1 READY_FOR_SMOKE в dry-run. Full live review/implement/publish round-trip не подтверждён.

Не своди current block к «tests не запускаются»: checks есть и зелёные на candidate. Не объявляй platform complete, потому что отдельный watcher installed. Следующее техническое решение должно учитывать действующие governance и сохранять final human promotion.

## 9. AGENT-LOOP-001: протокол и ограничения

### 9.1 Каналы

Новый control bus — только top-level PR conversation comments. Issue #1 = historical/manual PoC handoff, не watcher trigger. Issue #3 = install/migration audit. Inline reviews/code comments и examples не равны authoritative protocol decision.

### 9.2 Handoff

Ниже справочный пример; placeholders не являются действительным trigger.

```text
PROTOCOL: AGENT_LOOP_V1
TYPE: HANDOFF
STATUS: READY_FOR_REVIEW | BLOCKED
ITERATION: <bounded iteration>
BRANCH: <actual PR head branch>
CANDIDATE_SHA: <actual 40-character SHA>

CHANGED_FILES:
- <actual paths>
CHECKS:
- <command: outcome, tested revision/evidence>
IMPLEMENTED:
- <actual scope>
DEVIATIONS:
- none | <actual deviations>
DEFECTS_FOUND:
- none | <actual defects>
BLOCKERS:
- none | <actual blockers>
NEXT_ACTION:
REVIEW
```

### 9.3 Decision

```text
PROTOCOL: AGENT_LOOP_V1
TYPE: REVIEW_DECISION
ITERATION: <iteration>
REVIEWED_SHA: <actual 40-character reviewed SHA>
DECISION: APPROVE | REQUEST_CHANGES | BLOCKED
HUMAN_REQUIRED: false | true

FINDINGS:
- <evidence-linked findings or none>
NEXT_ITERATION:
<explicit bounded instructions, or NONE>
NEXT_ACTION:
IMPLEMENT | HUMAN_GATE | STOP
```

Review exact candidate/diff/CI; recheck current head; один authoritative decision на SHA; no duplicate launch; IMPLEMENT требует непустой bounded NEXT_ITERATION. Fenced/quoted examples и duplicate singleton fields invalid. BLOCKED означает pause/notification, не automatic repair.

### 9.4 Последний audit, не live state

Kit 1.3.1, bootstrap_version 1.3 by design, installed dry-run, permissions unverified, sandbox_required true. Reviewer login pending, reviewer_apps empty, operator sanches16, token file NOT_SET в audit. 28 tests reported PASS, включая 6 real sandbox tests на dummy files; full Claude session и CAS push не проверены.

Оставшиеся prerequisites: real reviewer author/app и primary/fallback ownership; private token prerequisite; main protection; throwaway protocol tests; real broker/model connectivity и tool network denial; actual Claude sandbox; planted-hook rejection; moved/closed PR и STOP; baseline; отдельно разрешённая activation; first descendant CAS push/HANDOFF/dedupe.

Правила kit: deny-default sandbox, scratch HOME/TMPDIR, isolated control plane/.git/credentials; inference только через localhost broker allowlist; trusted publisher absolute Git/hooks disabled/config validated; descendant-only compare-and-swap against reviewed SHA и fresh PR/STOP checks; flock; doctor exit 2 при active lock/unacked pause. Обычный force push, skip permissions, auto-merge, branch deletion и deploy не разрешены.

Kit живёт вне product repo на Mac. Не считать его файлы импортированными в canonical repo. Не читать/показывать реальные token/config secrets при ознакомлении.

## 10. Продуктовая master-spec: что будет после PoC

### 10.1 Архитектура

Next.js/TypeScript/React/Tailwind, PostgreSQL, Drizzle + SQL migrations, Docker Compose, modular monolith. Planned modules catalog/media/marketplace/search/listings/pricing/auth/integrations/audit/backup/notifications. Это target, не требование создать их все сейчас.

Application = source of truth. Primary client Web/PWA, iPhone + desktop, один private user, default Workspace в DB без multi-workspace UI, category attributes JSONB. No public registration/tags/microservices/mandatory Telegram/marketplace swarm.

### 10.2 Domain entities

| Entity | Существенные поля / правила |
| --- | --- |
| Workspace | Один default в MVP; owner/access согласно будущей SPEC |
| Item | UUID, unique seed_key, workspace, title/brand/model/category, priority 1..5, manual_order, intent/retention, attributes JSONB, notes, timestamps |
| ItemImage | item/storage_key, source, MIME, dimensions, SHA-256, is_primary, timestamp |
| ItemPriceTarget | reference/target/buy_now, amount/currency/time/source/active; history preserved |
| MarketplaceQuery | item/provider/query/location/delivery flag/seller filter/active |
| SearchRun | status, unique idempotency_key, requested location/times/trigger/error/raw result |
| SearchRunItem | Immutable task snapshot priority/query/target price |
| Listing | provider/external_id/canonical URL, seller, condition, completeness, location/delivery, first/last seen, active, risk/raw payload |
| ItemListing | Item↔Listing relevance/price score, recommendation label, suspicious, notes |
| PriceSnapshot | listing, amount/currency/captured_at/search_run; append observations |
| RejectedListing | external_id/search_run/reason/time, compact |

Intent = active/watching/paused/purchased; retention = live/archived/trash. Purchase и archive независимы. Permanent delete только из trash с явным подтверждением. One physical model = one Item; комплектация в Listing.

### 10.3 UX / pricing / search invariants

- Сохранять 15 canonical items, photos, pictograms, stars, manual controls.
- Sort priority DESC/manual_order ASC/created_at ASC; new priority placement after existing group.
- Manual order persists across refresh/restart/sort mode; edge behavior уточнить в Catalog Core.
- Reference stale after 30 days, видно пользователю, не auto-replaced агентом.
- SUPER/GOOD/NORMAL/EXPENSIVE deterministic by thresholds; SUSPICIOUS отдельный flag, price<40% актуального reference — минимальное правило.
- Avito default Moscow, delivery flag отдельный; Item no Avito-specific fields.
- Search agent inspect ≥20 cards, return ≤5 best; no fabricated completion evidence.
- Versioned result JSON Schema; no silent partial import on invalid payload.
- Listing dedupe provider+external_id, then canonical URL/fingerprint.
- Canonical images app-controlled; MIME/size/EXIF/hash/dedupe/thumbnail.
- Server never stores Avito password/cookies/session/browser profile.
- Offline destructive writes outside MVP.

### 10.4 Roadmap и границы

| Stage | In scope | Не делать в этом stage |
| --- | --- | --- |
| Platform PoC сейчас | Truthful health, tests/CI, process evidence | Product domain, ORM, seed, backup, UI, deploy |
| Product Iteration 0 | Drizzle/migrations; Workspace/Item/Image/needed price targets; seed; media; server-rendered verification; persistence; backup/restore; report | Full UI, stars/reorder, CRUD, auth/OAuth, SearchRun/Listing, Avito, Telegram, VPS, Playwright, agent/PR automation |
| Iteration 1 | Catalog Core, priority/manual order, iPhone, UI tests | Unapproved search/alerts/scope expansion |
| Iteration 2 | CRUD + lifecycle + uploads | Premature marketplace automation |
| Iteration 3 | Search domain, listings/price history, result JSON import | Premature local automation |
| Iteration 4 | External/local browser agent workflow | Server-side Avito credentials |
| Iteration 5 | Telegram alerts SUPER/buy-now/failure | Unapproved Mini App/duplicated backend |

Tailscale first persistent remote access. VPS only after stable Iteration 1; off-site backup before production. Caddy/domain/OAuth и PWA/access split требуют отдельного active plan, не выводятся из readiness labels master-spec.

### 10.5 Product Iteration 0 acceptance

Migrations from zero; first seed exactly 15 Items и 15 primary images; second seed still 15, no duplicate keys/media, same priority/order; canonical photos SHA; persistent DB/media survive app recreation; server-rendered verification page reads without hydration; backup DB/media and isolated destructive restore-test; recovered counts/keys/hashes/priority/order equal baseline; lint/typecheck/tests; VERSION/CHANGELOG/SQL migrations; RESULT-ITER0-FINAL; commit and STOP. Product Iteration 1 не начинается автоматически.

### 10.6 Seed и исторический prototype

Master-spec содержит authoritative 15 seed records. Legacy prototype ids `dw-dcs579nt`, `dw-dcb118`, `dw-dcs438b`, `daewoo-davc1621li` отличаются от master seed_keys `dewalt-dcs579nt`, `dewalt-dcb118`, `dewalt-dcs438b`, `daewoo-davc-1621li`. Нужны явное mapping и hashes. Canonical image отсутствует → BLOCKED; не загружать похожую замену.

Legacy web prototype paused 6 октября: D1/R2/Sites, incomplete UI/PWA/export/tests, упрощённые statuses. Это отдельный исторический источник, не current codebase. Не переносить его architecture/status schema без сравнения с master и approved migration.

Master original SHA-256: `0bc307b0ab9df2ddb71d89fe07b8cebef74426e4cb55d1f5e66e8d56232b9d92`. HTML v0.1.2 SHA-256: `7bb649c11351f7175e18751acf555df3a919d472c03a9d46488711bb81e9b0df`. Сам HTML/assets этой docs publication не импортированы.

## 11. Практика работы и Definition of Done

### 11.1 Bounded implementation

Определи requirement/task ID, allowed paths, existing accepted behavior, exact pins, verification и stop point. Изменяй необходимый patch, не переписывай весь repo, не добавляй abstractions/dependencies для future roadmap. Same-file edits последовательно, baseline сохраняется. Не лечи unrelated warning ради clean-looking output.

Tests должны проверять важное observable поведение: fault/loss/recovery, timing, schema, preservation, restore, isolation. Не заменять real acceptance fake-only test. Документационную правку проверять как документацию, не добавлять mirror tests.

### 11.2 Перед commit/publish

Проверь diff и file set, whitespace/links, scope, secrets, generated/private files, README accuracy. Report tested revision отдельно от records commit. Сохрани actual command outcomes, prerequisite failures и deviations. Не используй destructive cleanup чужих projects/volumes и не публикуй `.env`, token, cookies или raw connection logs.

Final promotion исполняется только в рамках конкретного human authorization. Устаревший approval для другого SHA не разрешает new merge. Если ref сдвинулся, прочитай новый head и diff; не force-update stale baseline.

### 11.3 Handoff и STOP

Сформируй iteration/branch/SHA, changed files, checks, implemented, deviations, defects, blockers, next action. Используй active channel; external comments публикуются только по явному действующему разрешению. В manual lane STOP после handoff; в активированном agent-loop следующий шаг должен прийти через valid bounded decision. Green CI не создаёт такой decision.

### 11.4 Обновление контекста

После принятого milestone обновить этот документ и human overview: snapshot/date, branch/SHA, evidence links, stage, pending work, next action. Не переносить historical PASS на current head. Reference originals сохранить byte-for-byte; amendments оформлять отдельно. Metrics и ratings не придумывать.

## 12. Подключение к Cursor

В repo добавлено короткое always-apply правило `.cursor/rules/tool-hunter-context.mdc`: оно даёт критичный baseline и просит прочитать этот файл перед substantive work. Полный context не нужно дублировать в каждом prompt. В Cursor можно явно приложить `docs/CURSOR_CONTEXT_RU.md` и active spec/task к текущему заданию.

Project rules `.mdc` и `alwaysApply` описаны в [официальной документации Cursor](https://cursor.com/docs/rules). Ссылка на файл в rule не гарантирует автоматическую вставку всего файла: агент должен прочитать его инструментом. Rule не заменяет permissions, source review или sandbox.

Стартовый запрос для read-only onboarding:

```text
Прочитай docs/CURSOR_CONTEXT_RU.md и актуальные repository instructions.
Проверь branch/SHA, active spec и последние GitHub handoff/review records.
Верни approved scope, current status, evidence, gaps и next action.
Сейчас задача только восстановить контекст; implementation, merge,
переключение live automation и запуск продуктовой итерации не требуются.
```
