---
description: "Requirement-traced implementation tasks for PLATFORM-POC-001"
---

# Tasks: PLATFORM-POC-001 — Foundation Health

**Input**: Approved design documents in `specs/001-foundation-health/`: `spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/health.openapi.yaml`, `contracts/runtime.md`, and `quickstart.md`.

**Planning approval**: `reviews/HUMAN_GATE_2A.md` records APPROVE by sanches16 on 2026-10-07 for commit `088e3a3c6747657742632ea9cce938f61af2bb2d`. Current spec, constitution, plan and supporting design blobs match that record. Historical pending/draft text in those approved documents is preserved.

**Implementation prerequisite**: This file authorizes no implementation. Run analysis separately and obtain renewed HUMAN GATE #2B approval covering active task/analysis revisions (the existing #2B rejects the previous candidate), and commit the reviewed planning baseline before executing implementation tasks. Gate #2A alone does not approve these newly generated tasks. Retain the gate record under `specs/001-foundation-health/reviews/` with reviewer, date, reviewed revisions, decision and authorized next action. These prerequisites are outside this task-generation run.

**Tests**: Required by FR-009–FR-010 and the approved runtime contract. Use Node built-in runner/assertions, production-mode Next.js and real PostgreSQL; no extra test framework. Author assertions before behavior; the trusted shell later demonstrates rejection of false health and pass for correct behavior. No test substitution may become a production bypass.

**Organization**: Shared setup and foundation precede story phases US1 (P1), US2 (P2), US3 (P2), followed by cross-cutting completion criteria. All checkboxes intentionally remain open. Checkbox tasks are implementer file edits only; execution and human obligations are assigned in the non-checkbox matrix; implementation completion does not complete human decisions.

## Format: `[ID] [P?] [Story?] Description`

- `[P]` marks work on different files that can proceed together after the named prerequisites. It does not remove dependencies.
- Story-phase tasks carry `[US1]`, `[US2]` or `[US3]`; shared and final tasks carry no story label.
- Every task ends with requirement/success-criterion or story acceptance-scenario traceability. `USn.Am` refers to numbered acceptance scenario m of story n in `spec.md`.
- Paths are relative to repository root. Evidence and work status use `docs/poc/PLATFORM-POC-001-RESULT.md`; existing human records remain intact.

**Binding rules**: `.specify/workflows/platform-poc-001/prompts/tasks-rules.md`. The implementer only reads/creates/edits repository files (plus read-only Git status/diff/log). It never executes npm/npx/node, Docker, gh, commits/pushes, convergence or critique, or records human decisions/ratings. T001 alone owns `package.json`; any later script/dependency correction belongs to T001. The implementer never creates `package-lock.json`. The trusted workflow shell generates it after implementation with `npm install --package-lock-only --ignore-scripts`, then runs `npm ci`. File edits do not establish verified completion.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the approved single root application and independent static-check interfaces.

- [ ] T001 Initialize only `package.json` for Node.js 24/npm; for every exact pinned npm dependency version, use the value supplied by the workflow's implementation inputs (`implementation-inputs`, `.agent-out/implementation-inputs.json`), covering Next.js, required React/React DOM, `pg`, TypeScript, necessary type declarations, ESLint and compatible Next.js lint configuration; define all scripts: `dev`, production `start`, `build`, independent ESLint `lint`, `typecheck` (prepare any required framework route types then strict no-emit checking independently of build/DB), Node built-in runner `test` targeting `tests/integration/health.test.mjs`, and `verify:startup` targeting `scripts/verify-startup.mjs`. This task solely owns script/dependency corrections; no ORM or extra framework and no implementer-created lockfile. (FR-001, FR-009, FR-014; SC-004)
- [ ] T002 [P] Configure only TypeScript configuration in `tsconfig.json` and framework declarations in `next-env.d.ts` for strict no-emit checking and generated route types, compatible with T001’s typecheck interface on a fresh install without earlier build or DB configuration; script corrections belong to T001. (FR-009; SC-004; US3.A1)
- [ ] T003 [P] Configure only `eslint.config.mjs` to lint application source, configuration and JavaScript tests/scripts using T001’s pinned compatible Next.js configuration and independent lint interface; script corrections belong to T001. (FR-009; SC-004; US3.A1)
- [ ] T004 Preserve existing ignore rules and update `.gitignore` to exclude local `.env` variants, generated build/type outputs and dependencies while explicitly allowing `.env.example`; exclude generated private test configuration/evidence intermediates from Git. (FR-007; SC-007; US2.A5)

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Provide a production-buildable shell and safe shared assertions. Complete this phase before story work.

- [ ] T005 [P] Add minimal App Router shell in `src/app/layout.tsx` and `src/app/page.tsx`, with essential `next.config.ts` only; ensure production build/start does not require secrets, database configuration or a database connection, and add no product UI, images or domain behavior. (FR-001, FR-009, FR-014; US2.A1)
- [ ] T006 [P] Create shared HTTP assertion helpers in `tests/helpers/health-assertions.mjs`: exact HTTP 200/503, exact three-field JSON with no extra properties, JSON content type and `Cache-Control: no-store`; monotonic request timing with ≤5,000 ms assertion and a watchdog exceeding five seconds (six seconds), where timeout/disconnect/missing body is failure; emit only phase/index/status/body/elapsed summaries with no private connection data. (FR-003–FR-005, FR-007, FR-009; SC-002–SC-004)

## Phase 3: User Story 1 — Determine Full Foundation Health (Priority: P1) — MVP

**Purpose**: Fresh SQL evidence, truthful failure and recovery within the deadline.

**Independent Test (workflow-owned execution)**: Trusted shell exercises real production HTTP/PostgreSQL: 10 healthy → 10 DB-loss → 10 recovery with unchanged app ID/start time; cold/config/auth/query/silent failures yield exact 503 within five seconds; false-health assertion control is rejected. Runtime execution needs T015–T017. Stopped-app behavior is documented in T018.

### Test file authoring (required by FR-009)

- [ ] T007 [P] [US1] Create the minimal silent TCP listener in `tests/fixtures/stalled-postgres.mjs`, accepting but never answering PostgreSQL protocol messages; expose test-owned listening port and counts of only its own ACTIVE accepted sockets (remove closed sockets from the active set), including the pre-request baseline and bounded close/destroy controls for repeated-timeout cleanup assertions, without logging credentials or creating an application bypass. (FR-004, FR-005, FR-009; SC-003; spec Edge Cases)
- [ ] T008 [P] [US1] Create isolated fixture definitions in `tests/compose.test.yaml` for production-mode app, real PostgreSQL, cold unreachable/invalid-config/authentication variants and the silent listener; bypass initial DB-ready ordering only for failure variants, use dynamically published loopback HTTP ports, unique project-owned disposable storage and test-generated credentials, and never consume private developer `.env` values. Use standalone test definitions so authoring does not depend on later production Compose files; keep planned service/image interfaces aligned with T015–T016, and for the PostgreSQL 17 fixture image reference with digest use the value supplied by the workflow's implementation inputs. Mount the test-only listener and expose active-socket counts to the runner through a test-only control interface. (FR-002, FR-004–FR-007, FR-009; SC-002–SC-004)
- [ ] T009 [US1] Add Node integration lifecycle and the real 10 healthy → 10 DB-loss → 10 recovery sequence in `tests/integration/health.test.mjs`, using T006 and T008; bound readiness, run fault cases sequentially, record unchanged app ID/process start time, time every request, reject cached/hard-coded healthy results and always clean only owned containers/network/volumes even on failed setup/assertions. Missing Docker/Compose must fail rather than skip. (FR-002–FR-005, FR-009; SC-002–SC-004; US1.A1, US1.A2, US1.A4)
- [ ] T010 [US1] Extend `tests/integration/health.test.mjs` with first-request unreachable/refused DB, invalid credentials, each missing/empty required configuration field and invalid port syntax/range. Add exactly 5 repeated silent-listener requests: assert exact HTTP 503/no-store and HTTP response deadline <= 5000 ms for each; after each response allow at most 1000 ms cleanup grace and assert the fixture’s count of only its own ACTIVE accepted sockets returns to the pre-request baseline within that grace; after all 5 repetitions assert active socket count equals the baseline. Measure cleanup grace after the response; it does not extend the HTTP deadline. Assert no unhandled errors and app survival; generate private values in owned fixtures and sanitize failures. Cleanup parameters are test determinism only, with no HTTP contract change. (FR-004–FR-007, FR-009; SC-003, SC-007; US1.A3; US2.A3, US2.A5; binding rules A1)
- [ ] T011 [US1] Add focused checks in `tests/integration/health.test.mjs` using the code-level test-client injection interface supplied by T013 (edit only the test file in this task) to simulate successful connection followed by query rejection/hang, unexpected SQL result and late success; verify failure within the shared deadline, resource reclamation and no late healthy transition. Feed a deliberately false 200/full-health response into T006's unavailable assertion and require it to throw; retain the real DB-stop test as independent protection. (FR-002–FR-005, FR-009; SC-004; US3.A2; runtime contract Required test assertions)
### Health implementation

- [ ] T012 [US1] Implement server-side configuration validation in `src/lib/database-health.ts` with one snapshot per request and no fallback: POSTGRES_HOST — "Required, nonempty, explicit destination; Compose app uses `db`"; POSTGRES_PORT — "Required, digits only, range 1–65535; Compose app uses `5432`"; POSTGRES_DB — "Required, nonempty; same database initialized by Compose"; POSTGRES_USER — "Required, nonempty; same local role initialized by Compose"; POSTGRES_PASSWORD — "Required, nonempty; locally supplied, never versioned or echoed". Preserve supplied passwords and return unavailable for invalid values without exposing host/db/user/password or raw driver errors. (FR-006, FR-007; US2.A2, US2.A3, US2.A5; data-model.md Environment configuration)
- [ ] T013 [US1] Implement a fresh short-lived `pg` client and validated `SELECT 1` result per observation in `src/lib/database-health.ts`; use one monotonic 4,000 ms total budget starting at handler entry before validation/connect/query, bound driver/server guards by remaining time, select unavailable for any error/deadline, destroy timed-out transport, clear timers, observe late errors and close clients without delaying response indefinitely. Allow only a code-level test-client injection boundary, never an environment/runtime bypass, and retain no prior healthy state. (FR-002–FR-005, FR-007; SC-002, SC-003; US1.A1–US1.A4)
- [ ] T014 [US1] Implement forced-dynamic Node-runtime GET in `src/app/api/health/route.ts`, starting the total probe deadline at handler entry and returning exact no-store JSON: status — "`ok` only after this request's successful SQL operation; otherwise `degraded`"; application — "`ok` whenever this running application returns a health response"; database — "`ok` after successful SQL; otherwise `unavailable`". Permit only HTTP 200 `ok/ok/ok` or HTTP 503 `degraded/ok/unavailable`, no additional JSON fields, and no secret-bearing diagnostics. (FR-002–FR-007; US1.A1–US1.A4; data-model.md Health observation; contracts/health.openapi.yaml)

## Phase 4: User Story 2 — Start From a Fresh Checkout (Priority: P2)

**Purpose**: Container runtime, safe configuration and repository-only lifecycle instructions.

**Independent Test (workflow-owned execution)**: A developer follows README from a fresh checkout with zero source edits/chat requests: configure/start/check, DB-only loss/recovery, verify and shutdown. Missing/invalid configuration never reports full health; private files remain ignored/untracked.

- [ ] T015 [P] [US2] Add `Dockerfile` using Node.js 24 for application runtime/build and `npm ci`; for the Node 24 image reference with digest in every base stage, use the value supplied by the workflow's implementation inputs; add `.dockerignore` excluding private `.env` variants, Git/private local state and generated host outputs while permitting the safe example. Define stages that build the production app without any database secrets or connection and run the production server. (FR-001, FR-007, FR-009; SC-001, SC-007; US2.A1, US2.A5)
- [ ] T016 [US2] Add `compose.yaml` with `app` and PostgreSQL 17 `db`; for the PostgreSQL 17 image reference with digest, use the value supplied by the workflow's implementation inputs; configure a local named volume, initial `pg_isready` dependency gate, loopback HTTP port 3000 and no host DB port; use the same environment-selected DB/user/password, app destination `db:5432`, required-value interpolation exposing only missing variable names, no restart cascade on DB loss, and ordinary stop/start/down behavior retaining the local volume. Keep the concrete DB digest in this configuration and consistent with the test fixture pin. (FR-001, FR-004, FR-006, FR-007; US1.A2, US1.A4; US2.A1–US2.A4; contracts/runtime.md)
- [ ] T017 [P] [US2] Add `.env.example` with POSTGRES_HOST=db, POSTGRES_PORT=5432, POSTGRES_DB=foundation, POSTGRES_USER=foundation and exactly one empty POSTGRES_PASSWORD= line; explain locally supplied password and no public database variables/credential URLs. Keep the example compatible with T004’s ignore rules (file edits only). (FR-006, FR-007; SC-007; US2.A2, US2.A5)
- [ ] T018 [US2] Write `README.md` using `specs/001-foundation-health/quickstart.md` and runtime contract: Node 24/npm/Docker/Compose/Git/curl/Python prerequisites, `npm ci`, non-overwriting example copy/local password setup, ignore/untracked checks, `docker compose up -d --build --wait --wait-timeout 120`, plain `up -d` after build, exact 200/503 bodies/no-store, DB-only stop/start and same-app identity checks, five npm checks and `docker compose down`; explain no response from stopped app and existing-volume credential behavior, with no source edits/chat dependency or private-value output. (FR-001, FR-006–FR-009; SC-001; US1.A5; US2.A1–US2.A5)

## Phase 5: User Story 3 — Verify and Resume the SDD Experiment (Priority: P2)

**Purpose**: Independent startup/CI checks and a repository handoff/result structure.

**Independent Test (workflow-owned execution)**: All five checks pass outside an agent and push/PR CI publishes SHA-linked outcomes. Implementer/reviewer each recover scope/status/evidence/gaps/next action from repository records; convergence, critique/skip, Human decision and all measurements/ratings complete the evidence.

- [ ] T019 [P] [US3] Implement `scripts/verify-startup.mjs` for `npm run verify:startup`: require Docker/Compose, generate private ephemeral configuration, own a unique isolated Compose project with disposable volume and dynamic loopback HTTP port using `tests/compose.test.yaml`, build/start with bounded readiness, use `tests/helpers/health-assertions.mjs` for exact healthy HTTP/body/no-store, then shut down and clean only owned resources even on failure; startup/assertion/cleanup failures exit nonzero, with safe output only. (FR-001, FR-007, FR-009; SC-004; US3.A1)
- [ ] T020 [P] [US3] Add `.github/workflows/ci.yml` on `push` and `pull_request` with read-only repository permissions, Node 24 and required Docker/Compose; run `npm ci` and all five identical local commands (`lint`, `typecheck`, `build`, `npm test`, `verify:startup`), with independent check outcomes and any nonzero result failing CI. Generate only job-local private values and retain sanitized SHA/job-URL-linked summaries/status including failures; upload no env files, raw driver errors or private connection data and add no AI, repair or merge job. (FR-007, FR-009, FR-010, FR-014; SC-004, SC-005; US3.A1, US3.A2)

- [ ] T021 [US3] Create only the initial `docs/poc/PLATFORM-POC-001-RESULT.md` structure with explicit pending/not-measured placeholders for checked SHA/branch/date/verifier; participating tool versions (Codex/Claude/Grok/Spec Kit/Docker/Node/npm/Compose and nonparticipation); procedures, prerequisites, expected/observed results, exit codes, sanitized evidence links and FR/SC mapping; CI URL/status; active intent/gate revisions; task-linked changes/commits, gaps/deviations and next action; manual cross-agent copy/paste, context re-explanation, human gate, repair cycle, convergence gap, useful new critic finding, scope deviation and broken SDD artifact counts; elapsed time and CI outcome; all six Human 1–5 ratings (setup difficulty, switching friction, artifact clarity, review confidence, resume experience, willingness to reuse); convergence/critique or not-performed status; final accept/request changes/abort, process suitability and reviewed revision/evidence/authorized next action. Link `docs/poc/PLATFORM-POC-001-RUN-HISTORY.md` without editing it and link existing intent/gate records. End the structure with a final `## Workflow-recorded evidence` section and leave that section empty for workflow-written marked evidence blocks. Actual outcomes, decisions and ratings are filled later by responsible workflow owners, never invented by the implementer. (FR-011–FR-014; SC-006–SC-008; US3.A3–US3.A7; data-model.md SDD work record)

## Phase 6: Polish & Cross-Cutting Concerns

No additional implementer edits are justified by the approved scope. Cross-cutting scope/secret review, verification, final evidence and decisions belong to the workflow matrix below. No optional refactoring, performance project, product UI, schema/migrations, new orchestration or deployment is added.

## Workflow-owned verification and human obligations

This section contains no checkbox tasks. Evidence is revision-linked, sanitized and recorded by the indicated workflow owner; pending/failing evidence keeps the affected work incomplete. Existing approvals remain intact; renewed task/analysis approval is required before implementation. All result references below mean `docs/poc/PLATFORM-POC-001-RESULT.md`.

| requirement / SC | responsible workflow stage | owner (shell / Codex / Grok / Human) | expected evidence artifact |
| --- | --- | --- | --- |
| FR-001, FR-009, FR-014; SC-004 — exact implementation inputs | implementation-inputs | shell | Read-only resolution recorded in `.agent-out/implementation-inputs.json`, handed to implementer: exact compatible npm versions for T001, Node 24 image reference with digest for T015 and PostgreSQL 17 image reference with digest for T016/test fixtures. No implementer lookup or version selection. |
| FR-001, FR-009; SC-004 — lockfile and five independent checks | local-checks | shell | Generate missing `package-lock.json` with `npm install --package-lock-only --ignore-scripts`, then exactly `npm ci`, `npm run lint`, `npm run typecheck`, `npm run build`, `npm test`, `npm run verify:startup`. Sanitized exit codes/summaries tied to the tested tree; typecheck precedes build, build requires no DB/secrets, missing prerequisites fail rather than skip. Shell owns lockfile generation. |
| FR-002–FR-007, FR-009; SC-002–SC-004; US1.A1–US1.A4; US2.A3, US2.A5 — SQL, faults, deadline and cleanup | local-checks | shell | Real 10/10/10 integration evidence; first-request refused/unreachable, auth/config, query rejection/hang/unexpected result/late success; exact bodies/no-store and monotonic timing <=5000 ms; false 200/full-health assertion rejected. T010: 5 silent requests; fixture-owned ACTIVE sockets return to pre-request baseline within <=1000 ms after each 503 and equal baseline after all 5. Cleanup grace never extends HTTP deadline; app survives without unhandled errors. Sanitized output under `.agent-out/evidence/`, later criterion-mapped in RESULT. |
| FR-001–FR-008; SC-001–SC-003; US1.A1–US1.A5; US2.A1–US2.A4 — production Compose lifecycle | docker-health | shell | Ephemeral-config production Compose startup → exact 200 → DB stop → exact 503 within <=5 s → DB start/readiness → exact 200 with unchanged app container/process → app stop → no response; cleanup only own resources. No private developer `.env` consumed. Safe lifecycle/timing evidence under `.agent-out/evidence/`, later recorded in RESULT. |
| FR-007, FR-011, FR-014; SC-006–SC-007 — tested implementation retention, scope and secrets | implement-commit | shell | Diff/secret-checked task-linked commit and push of the tested tree including shell-generated lockfile. Review dependencies, image exclusions and ignored/untracked local env files; prohibited scope or secrets block commit. Preserve approved intent/workflow files; retain checked SHA and task links for repository-only resumption. |
| FR-010–FR-011; SC-005; US3.A2 — deterministic push/PR parity | ci | shell | Observe actual GitHub Actions run of the implementation commit; SHA/job URL, same five core check statuses and sanitized summaries including failures. Missing run is not pass; CI uses no agent to execute/judge checks and uploads no private values. |
| FR-009–FR-011, FR-013; SC-001–SC-006, SC-008 — verification records | record-results + results-commit | shell | Write tested SHA, tool versions, exact local/Docker/CI commands, expected/observed outcomes, exit codes, timings and FR/SC mapping into `docs/poc/PLATFORM-POC-001-RESULT.md`, including marked blocks under `## Workflow-recorded evidence`; diff/secret-check and make a separate records-only commit. Checked implementation SHA remains distinct from records SHA. |
| FR-011–FR-012; SC-006; US3.A3–US3.A4 — convergence and resumable review | converge | Codex | Revision-linked `specs/001-foundation-health/reviews/CONVERGE.md` against committed intent/code/diff/evidence, traceable gaps or evidence of none. Workflow links report from RESULT. Reviewer identifies scope/status/evidence/gaps/next action using repository records alone. Gaps need Human direction and appropriate reverification; no autonomous repair. |
| FR-012–FR-013; US3.A5 — optional independent critique | critic | Grok | Optional read-only revision-linked report under `specs/001-foundation-health/reviews/`, linked from RESULT by workflow; useful new findings retained. If skipped, workflow records explicit `not performed` and nonparticipation. No source edits or repair authorization. |
| FR-008, FR-011–FR-013; SC-001, SC-006, SC-008; US2.A1–US2.A5; US3.A3, US3.A7 — human observations and experiment values | metrics-gate | Human | Human provides actual FR-013 counts and six 1–5 ratings, platform decision/process suitability; fresh-checkout zero-source-edit/zero-chat-request and implementer/reviewer repository-only resume observations. Validate from run history and retained evidence; placeholders or invented zeros are not completion. |
| FR-011–FR-014; SC-006–SC-008; US3.A7 — complete result before final gate | metrics-record | shell | Write Human-provided counts, all six ratings and platform decision into RESULT; retain tool versions, elapsed time, CI outcome, gate/repair/gap/critic/scope/broken-artifact counts, review links and next action. Workflow retains complete records in Git after diff/secret checks before final-gate. |
| FR-012, FR-014; SC-006–SC-008; US3.A4, US3.A6–US3.A7 — final decision and stop | final-gate | Human | Decision against the complete RESULT and reviewed revision/evidence: accept/request changes/abort, authorized next action and process suitability. No automatic merge/promotion; prior implementation approval/green CI is insufficient. At most one human-directed repair cycle before a new explicit decision for a second cycle. Workflow records decision in Git; stop further Tool Hunter iteration until explicit Human acceptance. |

## Dependencies & Execution Order

```text
Analysis + renewed HUMAN GATE #2B + reviewed baseline (workflow)
  → implementation-inputs (workflow shell)
  → T001 → T002/T003/T004 → T005/T006
  → US1 test authoring T007/T008 → T009 → T010 → T011
  → US1 probe T012 → T013 → T014
  → US2 runtime T015 → T016 (T017 env example may overlap T015) → README T018
  → US3 verifier/CI T019/T020 + result structure T021
  → shell lockfile/install → local-checks + docker-health
  → implement-commit → ci → record-results → results-commit
  → converge → Human convergence review/authorized repair if needed
  → critic or explicit skip → metrics-gate → metrics-record + records retention
  → final-gate (complete RESULT) + recorded Human decision → STOP
```

- The workflow resolves implementation inputs before any file task. T001 fixes all npm interfaces and uses exactly those supplied pins. T002–T004 use distinct files; T005–T006 follow setup and block story work.
- T007 and T008 may be authored together using their documented fixture interface. T009 follows both and T006. T010 and T011 follow sequentially because all three edit the same test file.
- T012 and T013 edit the same database helper sequentially; T014 follows T013. T011 only authors tests for the T013 injection interface; test execution awaits that implementation, so there is no authoring cycle.
- T015 and T017 may be authored together after foundation. T016 follows T015 and uses the fixed environment interface; its authoring does not depend on T017 being complete. T018 and runtime execution require both T016 and T017. T008 is standalone; production/test image pins must agree before workflow execution. US1 behavioral completion requires T015–T017 runtime even though tests and probe can be authored first.
- T018 follows health/runtime interfaces. T019 and T020 may be authored together after fixture/assertion/script interfaces are fixed. T021 is the sole initial result-file edit and follows those tasks; runtime evidence is subsequently workflow-owned.
- US2 startup depends on US1 health behavior. US3 execution depends on both stories and all verification file edits. This is one foundation slice with independent acceptance procedures, not three isolated applications.
- Same-file edits and database fault cases remain sequential. Workflow verification follows complete implementation, including trusted shell lockfile generation. Convergence/critique/human decisions follow actual revision-linked evidence; repairs require explicit Human direction and appropriate reverification.

### Parallel opportunities and examples

| Story/phase | File edits that can proceed together | Prerequisite |
| --- | --- | --- |
| Setup | T002 TypeScript, T003 ESLint and T004 ignore rules | T001 interfaces fixed; no additional manifest owner |
| Foundation | T005 framework shell and T006 assertions | Setup complete |
| US1 | T007 silent fixture and T008 test Compose definitions | Foundation complete; agree fixture/control interface |
| US2 | T015 Dockerfile/context exclusions and T017 safe env example | Foundation complete |
| US3 | T019 startup verifier and T020 CI configuration | Script/fixture/assertion interfaces fixed |

These examples describe scheduling only. They do not request agent delegation or shell execution by the implementer.

## Implementation Strategy

1. After separate analysis and renewed revision-linked task approval, implement Setup and Foundation.
2. Author US1 tests and implement the probe/route, together with essential US2 container/config files T015–T017. The shell validates truthful 10/10/10 health, cold/silent failures, deadlines and cleanup. This is the behavioral MVP; full PoC acceptance still needs US2/US3.
3. Finish fresh-checkout README, independent startup/CI infrastructure and initial result placeholders. The trusted shell generates the lockfile, installs and runs required local/Docker checks, then commits/pushes task-linked patches and observes CI.
4. The shell records local/Docker/CI evidence and commits those records separately. Codex converges against committed intent; Human directs any repair. Grok optionally critiques read-only or skip is recorded. Human supplies counts, ratings and platform decision at metrics-gate; the shell writes and retains the complete RESULT before final-gate. Human then decides final acceptance/promotion against that revision. The workflow records the decision and stops until explicit acceptance of further iteration.

## Notes

All 21 checkboxes remain unchecked. Every checkbox contains exact repository file paths and FR/SC or acceptance-scenario references. No verification, evidence observation, command execution, human decision, rating, commit/push or promotion is an implementer checkbox. Constitution v1.0.0 and all eight principles/Governance remain binding: reviewed intent before code, canonical patches, reproducible evidence, independent checks, bounded scope, Human promotion, secret exclusion and existing process tooling. No approved input, gate record or `.specify/workflows/` file is changed by this generation.
