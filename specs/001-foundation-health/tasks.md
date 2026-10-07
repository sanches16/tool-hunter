---
description: "Requirement-traced implementation tasks for PLATFORM-POC-001"
---

# Tasks: PLATFORM-POC-001 — Foundation Health

**Input**: Approved design documents in `specs/001-foundation-health/`: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/health.openapi.yaml`, `contracts/runtime.md`, and `quickstart.md`.

**Planning approval**: `reviews/HUMAN_GATE_2A.md` records APPROVE by sanches16 on 2026-10-07 for commit `088e3a3c6747657742632ea9cce938f61af2bb2d`. Current spec, constitution, plan and supporting design blobs match that record. Historical pending/draft text in those approved documents is preserved.

**Implementation prerequisite**: This file authorizes no implementation. Run analysis separately, obtain the remaining human plan/task review covering active artifact revisions (HUMAN GATE #2), and commit the reviewed planning baseline before executing implementation tasks. Gate #2A alone does not approve these newly generated tasks. Retain the gate record under `specs/001-foundation-health/reviews/` with reviewer, date, reviewed revisions, decision and authorized next action. These prerequisites are outside this task-generation run.

**Tests**: Required by FR-009–FR-010 and the approved runtime contract. Use Node built-in runner/assertions, production-mode Next.js and real PostgreSQL; no extra test framework. Write assertions before behavior, demonstrate failure when the target behavior is absent, then demonstrate pass. No test substitution may become a production bypass.

**Organization**: Shared setup and foundation precede story phases US1 (P1), US2 (P2), US3 (P2), followed by cross-cutting review. All checkboxes intentionally remain open. Process/reviewer/human tasks are assigned explicitly; implementation completion does not complete human decisions.

## Format: `[ID] [P?] [Story?] Description`

- `[P]` marks work on different files that can proceed together after the named prerequisites. It does not remove dependencies.
- Story-phase tasks carry `[US1]`, `[US2]` or `[US3]`; shared and final tasks carry no story label.
- Every task ends with requirement/success-criterion or story acceptance-scenario traceability. `USn.Am` refers to numbered acceptance scenario m of story n in `spec.md`.
- Paths are relative to repository root. Evidence and work status use `docs/poc/PLATFORM-POC-001-RESULT.md`; existing human records remain intact.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the approved single root application and independently executable static checks after the implementation gate.

- [ ] T001 Initialize `package.json` and `package-lock.json` for Node.js 24/npm with compatible stable Next.js, required React/React DOM, `pg`, TypeScript, necessary type declarations, ESLint and compatible Next.js lint configuration; lock exact resolved versions, record Node/npm/package versions in `docs/poc/PLATFORM-POC-001-RESULT.md`, and add `dev`, production `start`, `build`, `lint`, `typecheck`, Node-runner `test`, and `verify:startup` scripts targeting the planned files (later tasks supply test/startup files); install no ORM or extra framework. (FR-001, FR-009, FR-013, FR-014)
- [ ] T002 [P] Configure strict no-emit TypeScript in `tsconfig.json` and framework declarations in `next-env.d.ts`; make `package.json`'s `typecheck` prepare any required Next.js route types so it runs after `npm ci` without a preceding build or database configuration. (FR-009; SC-004; US3.A1)
- [ ] T003 [P] Configure `eslint.config.mjs` to lint application source, configuration and JavaScript tests/scripts using the locked compatible Next.js configuration; ensure `package.json`'s `lint` command exits nonzero for violations independently of build. (FR-009; SC-004; US3.A1)
- [ ] T004 Preserve existing ignore rules and update `.gitignore` to exclude local `.env` variants, generated build/type outputs and dependencies while explicitly allowing `.env.example`; exclude generated private test configuration/evidence intermediates from Git. (FR-007; SC-007; US2.A5)

**Dependencies**: T001 precedes T002–T004; T002 and T003 only edit their own configuration files, with command interfaces established by T001.

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Provide a production-buildable shell and shared safe assertion infrastructure. Complete this phase before story implementation.

- [ ] T005 [P] Add minimal App Router shell in `src/app/layout.tsx` and `src/app/page.tsx`, with essential `next.config.ts` only; ensure production build/start does not require secrets, database configuration or a database connection, and add no product UI, images or domain behavior. (FR-001, FR-009, FR-014; US2.A1)
- [ ] T006 [P] Create shared HTTP assertion helpers in `tests/helpers/health-assertions.mjs`: exact HTTP 200/503, exact three-field JSON with no extra properties, JSON content type and `Cache-Control: no-store`; monotonic request timing with ≤5,000 ms assertion and a watchdog exceeding five seconds (six seconds), where timeout/disconnect/missing body is failure; emit only phase/index/status/body/elapsed summaries with no private connection data. (FR-003–FR-005, FR-007, FR-009; SC-002–SC-004)

**Checkpoint**: Static tooling, shell and response assertion interfaces exist. No application database tables, schemas, migrations or saved health observations are needed.

## Phase 3: User Story 1 — Determine Full Foundation Health (Priority: P1)

**Goal**: Every health response reflects a fresh SQL operation against the configured database within the approved deadline; recovery requires no app restart.

**Independent Test**: With the production app and real PostgreSQL, assert ten healthy responses, stop only DB, assert ten exact unavailable responses, restore DB readiness and assert ten healthy responses. App container ID/process start time remain unchanged. Cold failure, configuration/authentication failure and silent dependency return exact 503; every acceptance request finishes within five seconds. A stopped app provides no endpoint response (documented in US2).

### Tests for User Story 1

- [ ] T007 [P] [US1] Create the minimal silent TCP listener in `tests/fixtures/stalled-postgres.mjs`, accepting but never answering PostgreSQL protocol messages; expose test-owned listening port/socket counts and bounded close/destroy controls for repeated-timeout cleanup assertions, without logging credentials or creating an application bypass. (FR-004, FR-005, FR-009; SC-003; spec Edge Cases)
- [ ] T008 [P] [US1] Create isolated fixture definitions in `tests/compose.test.yaml` for production-mode app, real PostgreSQL, cold unreachable/invalid-config/authentication variants and the silent listener; bypass initial DB-ready ordering only for failure variants, use dynamically published loopback HTTP ports, unique project-owned disposable storage and test-generated credentials, and never consume private developer `.env` values. Keep base service/image behavior aligned with `compose.yaml` when T017 lands. (FR-002, FR-004–FR-007, FR-009; SC-002–SC-004)
- [ ] T009 [US1] Add Node integration lifecycle and the real 10 healthy → 10 DB-loss → 10 recovery sequence in `tests/integration/health.test.mjs`, using T006 and T008; bound readiness, run fault cases sequentially, record unchanged app ID/process start time, time every request, reject cached/hard-coded healthy results and always clean only owned containers/network/volumes even on failed setup/assertions. Missing Docker/Compose must fail rather than skip. (FR-002–FR-005, FR-009; SC-002–SC-004; US1.A1, US1.A2, US1.A4)
- [ ] T010 [US1] Extend `tests/integration/health.test.mjs` with first-request unreachable/refused DB, invalid credentials, each missing/empty required configuration field, invalid port syntax/range, and repeated silent-listener timeouts; assert exact 503/no-store and ≤5,000 ms, bounded transport release grace with no sustained socket growth, no unhandled errors and app survival. Generate all private values in owned fixtures and sanitize failures. (FR-004–FR-007, FR-009; SC-003, SC-007; US1.A3; US2.A3, US2.A5)
- [ ] T011 [US1] Add focused checks in `tests/integration/health.test.mjs` using a test-only injected client boundary in `src/lib/database-health.ts` to simulate successful connection followed by query rejection/hang, unexpected SQL result and late success; verify failure within the shared deadline, resource reclamation and no late healthy transition. Feed a deliberately false 200/full-health response into T006's unavailable assertion and require it to throw; retain the real DB-stop test as independent protection. (FR-002–FR-005, FR-009; SC-004; US3.A2; runtime contract Required test assertions)

### Implementation for User Story 1

- [ ] T012 [US1] Implement server-side configuration validation in `src/lib/database-health.ts` with one snapshot per request and no fallback: POSTGRES_HOST — "Required, nonempty, explicit destination; Compose app uses `db`"; POSTGRES_PORT — "Required, digits only, range 1–65535; Compose app uses `5432`"; POSTGRES_DB — "Required, nonempty; same database initialized by Compose"; POSTGRES_USER — "Required, nonempty; same local role initialized by Compose"; POSTGRES_PASSWORD — "Required, nonempty; locally supplied, never versioned or echoed". Preserve supplied passwords and return unavailable for invalid values without exposing host/db/user/password or raw driver errors. (FR-006, FR-007; US2.A2, US2.A3, US2.A5; data-model.md Environment configuration)
- [ ] T013 [US1] Implement a fresh short-lived `pg` client and validated `SELECT 1` result per observation in `src/lib/database-health.ts`; use one monotonic 4,000 ms total budget starting at handler entry before validation/connect/query, bound driver/server guards by remaining time, select unavailable for any error/deadline, destroy timed-out transport, clear timers, observe late errors and close clients without delaying response indefinitely. Allow only a code-level test-client injection boundary, never an environment/runtime bypass, and retain no prior healthy state. (FR-002–FR-005, FR-007; SC-002, SC-003; US1.A1–US1.A4)
- [ ] T014 [US1] Implement forced-dynamic Node-runtime GET in `src/app/api/health/route.ts`, starting the total probe deadline at handler entry and returning exact no-store JSON: status — "`ok` only after this request's successful SQL operation; otherwise `degraded`"; application — "`ok` whenever this running application returns a health response"; database — "`ok` after successful SQL; otherwise `unavailable`". Permit only HTTP 200 `ok/ok/ok` or HTTP 503 `degraded/ok/unavailable`, no additional JSON fields, and no secret-bearing diagnostics. (FR-002–FR-007; US1.A1–US1.A4; data-model.md Health observation; contracts/health.openapi.yaml)
- [ ] T015 [US1] After T016–T017 supply the container runtime, run `npm test` against `tests/integration/health.test.mjs`; retain checked SHA, exact command, exit code, safe per-request timing/classification, app identity/recovery and bounded cleanup results in `docs/poc/PLATFORM-POC-001-RESULT.md`. Confirm false-health negative control fails its assertion and actual DB-loss assertions would reject an always-healthy route; missing/failing evidence leaves US1 incomplete. (FR-009, FR-011; SC-002–SC-004; US1.A1–US1.A4)

**Checkpoint**: US1 is the behavioral MVP after its real container-runtime validation dependency. It is not permission for promotion or full PoC acceptance.

## Phase 4: User Story 2 — Start From a Fresh Checkout (Priority: P2)

**Goal**: Repository instructions and safe environment examples suffice to configure, start, check and stop the local foundation with zero source edits.

**Independent Test**: A developer with only a fresh checkout and prerequisites follows README configuration/startup, reproduces health/loss/recovery while app remains running, runs verification and shuts down. Missing configuration cannot report full health; local secrets remain ignored and absent from responses/shared diagnostics.

### Implementation and validation for User Story 2

- [ ] T016 [P] [US2] Add `Dockerfile` using the locked Node.js 24 application runtime/build and `npm ci`, with concrete base-image pin recorded in `docs/poc/PLATFORM-POC-001-RESULT.md`; add `.dockerignore` excluding private `.env` variants, Git/private local state and generated host outputs while permitting the safe example. Build the production app without any database secrets or connection and run the production server. (FR-001, FR-007, FR-009; SC-001, SC-007; US2.A1, US2.A5)
- [ ] T017 [US2] Add `compose.yaml` with `app` and PostgreSQL 17 `db`, concrete DB image digest, local named volume, initial `pg_isready` dependency gate, loopback HTTP port 3000 and no host DB port; use the same environment-selected DB/user/password, app destination `db:5432`, required-value interpolation exposing only missing variable names, no restart cascade on DB loss, and ordinary stop/start/down behavior retaining the local volume. Record pins without private values in `docs/poc/PLATFORM-POC-001-RESULT.md`. (FR-001, FR-004, FR-006, FR-007; US1.A2, US1.A4; US2.A1–US2.A4; contracts/runtime.md)
- [ ] T018 [P] [US2] Add `.env.example` with POSTGRES_HOST=db, POSTGRES_PORT=5432, POSTGRES_DB=foundation, POSTGRES_USER=foundation and exactly one empty POSTGRES_PASSWORD= line; explain locally supplied password and no public database variables/credential URLs. Verify `.gitignore` admits the example and excludes local variants. (FR-006, FR-007; SC-007; US2.A2, US2.A5)
- [ ] T019 [US2] Write `README.md` using `specs/001-foundation-health/quickstart.md` and runtime contract: Node 24/npm/Docker/Compose/Git/curl/Python prerequisites, `npm ci`, non-overwriting example copy/local password setup, ignore/untracked checks, `docker compose up -d --build --wait --wait-timeout 120`, plain `up -d` after build, exact 200/503 bodies/no-store, DB-only stop/start and same-app identity checks, five npm checks and `docker compose down`; explain no response from stopped app and existing-volume credential behavior, with no source edits/chat dependency or private-value output. (FR-001, FR-006–FR-009; SC-001; US1.A5; US2.A1–US2.A5)
- [ ] T020 [US2] Follow `README.md` from a fresh checkout of the candidate revision without source edits or chat context: configure safely, start/check/loss/recover/down, verify missing Compose configuration fails actionably and invalid direct-app config returns 503, check local env files are ignored/untracked and excluded from image context, and record procedure/tool versions/outcomes in `docs/poc/PLATFORM-POC-001-RESULT.md`. Use only owned local services; report gaps rather than claim success. (FR-001, FR-006–FR-008, FR-011; SC-001, SC-007; US1.A5; US2.A1–US2.A5)

**Checkpoint**: Fresh-checkout lifecycle is independently reproducible. T017 also enables US1's container-backed completion check T015.

## Phase 5: User Story 3 — Verify and Resume the SDD Experiment (Priority: P2)

**Goal**: Checks and revision-linked Git records allow implementer/reviewer resumption, deterministic judgment and human control of review/promotion.

**Independent Test**: All five commands pass outside an agent on the candidate SHA; push/PR CI publishes equivalent SHA-linked outcomes. One implementer and one reviewer independently recover scope/status/evidence/gaps/next action. Convergence and optional critique are recorded; final decision and every FR-013 measurement are present, with further iteration awaiting human acceptance.

### Verification infrastructure and evidence for User Story 3

- [ ] T021 [P] [US3] Implement `scripts/verify-startup.mjs` for `npm run verify:startup`: require Docker/Compose, generate private ephemeral configuration, own a unique isolated Compose project with disposable volume and dynamic loopback HTTP port using `tests/compose.test.yaml`, build/start with bounded readiness, use `tests/helpers/health-assertions.mjs` for exact healthy HTTP/body/no-store, then shut down and clean only owned resources even on failure; startup/assertion/cleanup failures exit nonzero, with safe output only. (FR-001, FR-007, FR-009; SC-004; US3.A1)
- [ ] T022 [P] [US3] Add `.github/workflows/ci.yml` on `push` and `pull_request` with read-only repository permissions, Node 24 and required Docker/Compose; run `npm ci` and all five identical local commands (`lint`, `typecheck`, `build`, `npm test`, `verify:startup`), with independent check outcomes and any nonzero result failing CI. Generate only job-local private values and retain sanitized SHA/job-URL-linked summaries/status including failures; upload no env files, raw driver errors or private connection data and add no AI, repair or merge job. (FR-007, FR-009, FR-010, FR-014; SC-004, SC-005; US3.A1, US3.A2)
- [ ] T023 [US3] Run `npm ci` then `npm run lint`, `npm run typecheck` before any production build, `npm run build` without DB configuration/live DB, `npm test`, and `npm run verify:startup`; record exact commands, checked SHA/branch/date/verifier/tool versions, expected/observed results, exit codes and sanitized outputs with criterion mapping in `docs/poc/PLATFORM-POC-001-RESULT.md`. Keep failing or unexecuted categories open. (FR-009, FR-011; SC-004; US3.A1)
- [ ] T024 [US3] For authorized push/PR runs of `.github/workflows/ci.yml`, verify both event configurations execute the same five checks, observe actual candidate-revision CI statuses, and record SHA, job URL, check outcomes and sanitized evidence links in `docs/poc/PLATFORM-POC-001-RESULT.md`; confirm the T011 false-health assertion control executes in CI. No missing run or agent claim counts as pass. (FR-010, FR-011; SC-005; US3.A2)

### Repository handoff and reviews for User Story 3

- [ ] T025 [US3] Maintain the work/evidence sections of `docs/poc/PLATFORM-POC-001-RESULT.md` throughout implementation: identify active constitution/spec/plan/tasks/gate revisions, link each implementation commit/change to task IDs, record deviations/gaps against criteria and next action, and keep `specs/001-foundation-health/tasks.md` checkboxes supported by evidence. Commit logical task-linked patches only after diff/staged-secret review; preserve approved intent and `.specify/workflows/` unchanged. (FR-007, FR-011, FR-014; SC-006, SC-007; US3.A3)
- [ ] T026 [US3] Implementer and reviewer each perform a repository-only resume assessment using `specs/001-foundation-health/tasks.md`, intent/gate records and `docs/poc/PLATFORM-POC-001-RESULT.md`; record each identity, checked revision, located scope/status/evidence/gaps/next action, and measured context re-explanations/cross-agent copy operations, without inventing zero counts. (FR-011, FR-013; SC-006; US3.A3)
- [ ] T027 [US3] Reviewer runs existing `$speckit-converge` against committed spec/plan/tasks and actual code/diff/evidence; record checked SHA, criteria, gaps or evidence of no gaps in `docs/poc/PLATFORM-POC-001-RESULT.md` and retain any traceable gap tasks in `specs/001-foundation-health/tasks.md`. Stop for human direction on gaps; allow at most one human-directed repair cycle, with a new explicit decision before a second cycle. Reverify changed criteria after an authorized repair. (FR-011, FR-012; SC-006; US3.A4)
- [ ] T028 [US3] Reviewer assembles read-only intent/diff/safe verification/convergence references for optional Grok critique and records critic identity, checked revision, findings/useful-new-finding count in `docs/poc/PLATFORM-POC-001-RESULT.md`; if skipped, explicitly record `not performed` and tool nonparticipation. Critique produces no source changes and findings do not authorize repairs. (FR-012, FR-013; US3.A5)
- [ ] T029 [US3] Human decision owner records the final promotion/acceptance decision in `docs/poc/PLATFORM-POC-001-RESULT.md`, identifying reviewer/date, candidate SHA, reviewed artifacts/evidence, accept/request changes/abort and exact authorized next action; passing checks do not grant approval, and this task performs no merge. Record whether the process is suitable for another iteration, with further work still subject to explicit acceptance. (FR-012–FR-014; SC-007, SC-008; US3.A6, US3.A7)
- [ ] T030 [US3] Complete `docs/poc/PLATFORM-POC-001-RESULT.md` with participating Codex/Claude Code/Grok Build/Spec Kit/Docker/Node versions (explicit nonparticipation where applicable); counts of manual cross-agent copy/paste, context re-explanations, human gates, repair cycles, convergence gaps, useful new critic findings, scope deviations and broken SDD artifacts; elapsed time and CI outcome; obtain actual human 1–5 ratings for setup difficulty, switching friction, artifact clarity, review confidence, resume experience and willingness to reuse. Link final decision/evidence and leave unavailable measurements pending rather than inventing them. (FR-013; SC-008; US3.A7; data-model.md SDD work record)

**Checkpoint**: US3 completion requires actual evidence and human records, not merely created scripts or templates. Pending decisions remain explicit.

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final criterion/scope/secret checks and committed handoff only; no discretionary refactoring or feature expansion.

- [ ] T031 Review actual candidate diff, `package.json`/`package-lock.json`, image/dependency pins, tracked/staged files, `.gitignore` and `.dockerignore`; record zero secrets, excluded product/domain/deployment work, prohibited orchestration and unauthorized promotions in `docs/poc/PLATFORM-POC-001-RESULT.md`, with explicit compliance evidence for all eight constitution principles and Governance v1.0.0. Confirm `.specify/workflows/` and approved input artifacts remain unchanged; findings block completion and secret-bearing commits. (FR-007, FR-012, FR-014; SC-007)
- [ ] T032 Reconcile every FR-001–FR-014 and SC-001–SC-008 against observed revision-linked evidence in `docs/poc/PLATFORM-POC-001-RESULT.md` and `specs/001-foundation-health/tasks.md`; check exact HTTP contract, 10/10/10 classification/deadlines/cleanup, fresh-checkout procedure, five command results, CI, task-linked changes, gates/convergence/critique and every metric. Missing/failing evidence keeps related tasks open; any scope/approach change returns to human review. (FR-001–FR-014; SC-001–SC-008)
- [ ] T033 After required results and human decision are present, inspect final diff/staged content for secrets and commit final `docs/poc/PLATFORM-POC-001-RESULT.md` and `specs/001-foundation-health/tasks.md` records with task links; distinguish tested code SHA from subsequent records-only commit, retain reviewed gate revisions and pending next action, then stop. Do not merge automatically or begin another Tool Hunter iteration without explicit human acceptance. (FR-007, FR-011, FR-013, FR-014; SC-006–SC-008)

## Traceability Coverage

The task-line references are authoritative mappings; this index makes omissions visible.

| Criterion | Principal tasks |
| --- | --- |
| FR-001 / SC-001 | T001, T005, T016–T020, T021 |
| FR-002 / SC-002 | T008–T015 |
| FR-003 | T006, T009, T014, T015 |
| FR-004 | T007–T015, T017 |
| FR-005 / SC-003 | T006–T015 |
| FR-006 | T008, T010, T012, T017–T020 |
| FR-007 / SC-007 | T004, T006–T014, T016–T022, T025, T029, T031, T033 |
| FR-008 | T019, T020 |
| FR-009 / SC-004 | T001–T003, T005–T011, T015, T016, T019, T021–T023 |
| FR-010 / SC-005 | T022, T024 |
| FR-011 / SC-006 | Implementation prerequisite, T015, T020, T023–T027, T032, T033 |
| FR-012 | Implementation prerequisite, T027–T029, T031 |
| FR-013 / SC-008 | T001, T026, T028–T030, T032, T033 |
| FR-014 | T001, T005, T022, T025, T029, T031–T033 |

## Dependencies & Execution Order

### Phase and story dependencies

```text
analysis → human review of active plan/tasks → committed planning baseline
  → Setup T001–T004 → Foundation T005–T006
    → US1 tests T007–T011 → implementation T012–T014 ─┐
    → US2 runtime T016–T018 ──────────────────────────┤
                                                    → T015 (US1 validation)
    → US2 README T019 → fresh-checkout validation T020
    → US3 infrastructure T021–T022 → local T023 → CI T024
    → handoff T025–T026 → convergence T027 → critique/skip T028
    → human decision T029 → complete measurements T030
    → cross-cutting T031–T033 → STOP
```

- All story work depends on T001–T006. US1 tests can be authored before runtime files exist, but executable real-container tests and US1 completion require T016–T017. This concrete dependency prevents an unsupported claim that US1 is a self-contained container increment before runtime setup.
- T009 follows T007–T008. T010 follows T009; T011 follows T010 because they edit the same test file. T012–T013 edit the same helper sequentially; T014 follows T013. Focused tests may initially fail because the helper boundary does not yet exist; do not mark them passing before implementation.
- T016 and T018 may proceed together; serialize their evidence-record updates. T017 follows T016 and T018, and T019 follows T017. Align T008 fixture definitions after T017 without concurrent edits. T020 needs T014 and T019; T015 needs T007–T014 and T016–T017.
- T021 and T022 may be authored in parallel once the test fixture/assertion interfaces exist. Execution of T023 requires US1/US2 runtime, tests and both verification commands. T024 follows available CI configuration and authorized revision publication.
- Begin T025 records as implementation starts and maintain them throughout; finish its completeness review after T023–T024. T026 follows completed handoff evidence. T027 depends on completed implementation and required verification; gap repairs pause the sequence pending human direction.
- T028 follows convergence; T029 is a human-owned decision after reviews. T030 collects measurements throughout and completes only after actual ratings/decision. Final tasks follow all story evidence and decisions; secret/scope checks also apply before every earlier commit.
- No task includes autonomous repair, promotion or workflow modifications. Existing process tooling is reused. Optional critique is the only optional stage; its skipped status is mandatory evidence.

### Parallel opportunities and examples

| Story/phase | Work that can proceed together | Required boundary |
| --- | --- | --- |
| Setup | T002 TypeScript and T003 ESLint configuration | T001 complete; do not concurrently edit `package.json` |
| Foundation | T005 shell and T006 HTTP helpers | Setup complete |
| US1 | T007 silent listener and T008 Compose fixtures | Foundation complete; test files differ |
| US2 | T016 container build and T018 safe environment example | Foundation complete; serialize result-record writes |
| US3 | T021 startup verifier and T022 GitHub Actions workflow | Fixture/helper interfaces fixed; actual checks await implementations |

These are scheduling examples, not requests to launch agents. Same-file test/helper edits, result-record updates, database fault scenarios, approvals and commits remain sequential. US1 test authoring and US2 runtime setup can overlap; final behavioral validation depends on their integration.

## Implementation Strategy

### MVP first

1. Complete analysis, revision-linked human task approval and the committed baseline.
2. Complete Setup and Foundation.
3. Author US1 tests, implement the SQL probe/route and supply US2's essential container/config tasks T016–T018.
4. Run T015 and demonstrate truthful 10/10/10 behavior, cold/silent failures and bounded cleanup. This is the behavioral MVP, not full experiment acceptance.

### Incremental delivery

1. Finish US2 documentation and fresh-checkout validation.
2. Finish US3 startup check, all five local checks and equivalent push/PR CI evidence.
3. Retain task-linked patches and handoff evidence; reviewer converges, optional critic reviews read-only or records skip, and human owns the final decision and ratings.
4. Complete cross-cutting checks and final records commit, then stop. No production deployment, product feature work, migrations, new orchestration or automatic merge is part of this feature.

## Notes

- Completion requires observed evidence at the checked revision. A generated task list, build script, gate template or green result on another revision is insufficient.
- Human ratings and decisions cannot be filled by an agent. Do independent authorized work while they are pending; dependent stages wait.
- All approved input artifacts and `.specify/workflows/` remain untouched by this task-generation run and by the scheduled implementation scope.
