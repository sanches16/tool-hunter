# Implementation Plan: PLATFORM-POC-001 — Foundation Health

**Branch**: `poc/platform-poc-001` | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

**Status**: Design complete; tasks, analysis and HUMAN GATE #2 pending. Implementation is not authorized.

**Input**: Approved spec and [constitution v1.0.0](../../.specify/memory/constitution.md), constrained
by [PLATFORM-POC-001 scope/exclusions](../../docs/poc/PLATFORM-POC-001.md). No future product specification is input.
[HUMAN GATE #1](reviews/HUMAN_GATE_1.md) records sanches16's planning approval on 2026-10-07,
reviewed commit `ec304ce0a2d4163eeffc302a1c5adaf2569df71c`. The current spec and constitution
match their approved blobs; the spec's draft label is preserved. Canonical planning baseline:
`694f77fd3f4e17006f3a3c6491f19eec94884158`.

## Summary

Build a minimal Next.js + TypeScript foundation with PostgreSQL and both services in Docker Compose.
GET `/api/health` performs a fresh `SELECT 1` against the configured database for every request.
Successful SQL completion returns the approved HTTP 200 body; configuration, connection, query
or timeout failure returns the approved HTTP 503 body. Disable caching. One total four-second
probe budget reserves one second for response handling within the five-second local acceptance bound.
No ORM, domain schema, migrations or product interface is needed.

Independent npm checks, real database integration tests, startup checks and GitHub Actions produce
deterministic revision-linked evidence. Git and Spec Kit retain task links, decisions and results.
This command creates planning documents only.

## Technical Context

**Language/Version**: Node.js 24 LTS baseline; TypeScript strict mode.

**Primary Dependencies**: Next.js App Router, its required React/React DOM packages, `pg`;
development dependencies limited to TypeScript, necessary type declarations, ESLint and compatible
Next.js lint configuration. Use npm with committed `package-lock.json`. Select compatible stable
releases and lock exact resolved versions during implementation; no latest-release claim is made.

**Storage**: PostgreSQL 17 as the selected PoC major, pinned to a concrete image digest during
implementation; local named Compose volume. No application tables, seed data or persistence contract.

**Testing**: Node.js built-in test runner/assertions; HTTP against a production-mode Next.js process
and real PostgreSQL. A minimal test-only TCP listener accepts connections without answering the
PostgreSQL protocol. Compose controls dependency failure and recovery. No additional test framework.

**Target Platform**: Local macOS/Linux with Node.js 24, npm, Docker Engine/Desktop and Compose v2;
GitHub Actions Linux runner with Docker. No production target.

**Project Type**: Single web application with a minimal framework shell and one health endpoint.

**Performance Goals**: Every handled acceptance request completes within five seconds. Ten healthy,
ten database-loss and ten recovered requests classify correctly. No load, startup-time or production SLA.

**Constraints**: Environment-only connection configuration; fresh SQL evidence per request;
secret-free responses and shared diagnostics; independently executable verification; human gates
before implementation and promotion; no autonomous repair. At most one human-directed repair cycle
before another explicit decision. No custom orchestration.

**Scale/Scope**: One developer-operated foundation, one required database, one HTTP route, one CI
workflow and repository-based evidence. Design choices are resolved in [research.md](research.md).
Exact package pins/image digests and observed runtime results are implementation outputs.

## Constitution Check

Active constitution: v1.0.0. PASS below means design compliance, not runtime success or human approval.

| Rule | Pre-research gate | Post-design evaluation and implementation condition |
| --- | --- | --- |
| I. SPEC BEFORE CODE | PASS: recorded HUMAN GATE #1 covers matching spec/constitution for planning. | PASS: documents only. Tasks and analysis follow separately; HUMAN GATE #2 must record reviewer, date and active spec/plan/task revisions before code. |
| II. PATCH THE CANONICAL REPOSITORY | PASS: existing branch, clean initial worktree and baseline inspected. | PASS: new artifacts only under this feature. Approved files and workflow files remain byte-for-byte unchanged; later implementation is a reviewable patch, with no repository rebuild or tooling reinstall. |
| III. DETERMINISTIC EVIDENCE OVER AGENT CLAIMS | PASS: FR-009–FR-013 require reproducible revision-linked evidence. | PASS: verification matrix and quickstart specify commands, expected results and records. Planning does not mark runtime criteria complete. Missing/failing evidence keeps tasks incomplete. |
| IV. TESTS MUST BE EXECUTABLE OUTSIDE THE LLM | PASS: independent checks required by spec. | PASS: npm lint/typecheck/build/test and Compose startup checks have explicit prerequisites/pass conditions; CI uses the same commands. No migrations apply because there is no schema. |
| V. NO SILENT SCOPE EXPANSION | PASS: approved boundaries reviewed; no exception needed. | PASS: only foundation, health, essential configuration, tests, CI and evidence. All source exclusions below remain binding. |
| VI. HUMAN PROMOTION GATE | PASS: no promotion authorized. | PASS: final approval must identify reviewed revision and evidence; green CI and implementation permission cannot authorize merge. |
| VII. SECRETS MUST NEVER ENTER GIT | PASS: safe templates and ignored local values required. | PASS: empty password example; local values excluded from Git/image context; fixed health bodies and sanitized diagnostics. Inspect proposed diff and staged content before every commit; detected secrets block commit. |
| VIII. NO CUSTOM ORCHESTRATION | PASS: use Spec Kit, Git, native CLIs and deterministic CI. | PASS: ordinary npm/Compose test commands only; no custom orchestrator, task queue, agent database, memory server or LLM gateway. Repository artifacts are the handoff bus. |
| Governance | PASS: no conflict with v1.0.0 identified. | PASS: no waiver/amendment. Conflicts halt implementation until human-reviewed spec correction or approved constitutional amendment; version changes require renewed compliance review. |

**Gate result**: PASS before Phase 0 and after Phase 1. HUMAN GATE #2 remains pending.

Out of scope: catalog/canonical 15 items, product UI/images, Tool Hunter domain schema,
Out of scope: authentication, PWA, Avito, SearchRun, backup/restore, Telegram, VPS, Caddy, production deployment,
Out of scope: Cline, Ruflo, custom orchestrators/task queues/agent databases/memory servers/LLM gateways,
Out of scope: autonomous repair loops and auto-merge. Further iteration requires explicit human acceptance.

## Project Structure

### Documentation (this feature)

```text
specs/001-foundation-health/
├── spec.md                         # approved; unchanged
├── checklists/requirements.md       # approved; unchanged
├── reviews/HUMAN_GATE_1.md          # existing; unchanged
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── health.openapi.yaml
│   └── runtime.md
└── tasks.md                        # future speckit-tasks output
```

### Source Code (repository root; proposed after HUMAN GATE #2)

```text
src/app/layout.tsx
src/app/page.tsx                     # minimal shell only
src/app/api/health/route.ts
src/lib/database-health.ts
package.json
package-lock.json
tsconfig.json
next-env.d.ts
next.config.ts
eslint.config.mjs
Dockerfile
.dockerignore
compose.yaml
.env.example
README.md
scripts/verify-startup.mjs
tests/integration/health.test.mjs
tests/helpers/health-assertions.mjs
tests/fixtures/stalled-postgres.mjs
tests/compose.test.yaml
.github/workflows/ci.yml
docs/poc/PLATFORM-POC-001-RESULT.md
```

**Structure Decision**: One root App Router project; `pg` confined to server-side Node runtime.
No separate frontend/backend packages or domain layers. Proposed scripts are finite deterministic
checks, not agent schedulers, repair loops or persistent state stores. Existing `.specify/workflows/`
is untouched.

## Phase 0 — Research

[research.md](research.md) resolves runtime, SQL probe, freshness, deadline/cleanup, configuration,
Compose lifecycle, independent verification and handoff. Research derives design decisions from
the approved requirements and constitution within POC scope; no external feature requirements.

## Phase 1 — Design

### Health and runtime

Use a forced-dynamic Node route and `Cache-Control: no-store`. Validate required configuration;
missing/invalid values yield 503 without fallback. Build must not connect to a database or need secrets.
Start the monotonic total 4,000 ms dependency deadline at handler entry, before parsing or connecting.
Open a fresh client, execute `SELECT 1` and verify its result. Success within budget yields 200;
all errors/deadlines yield 503. Late success cannot change an already selected failure response.
Cancel/destroy timed-out transport, clear timers, observe asynchronous errors and close clients.
Cleanup must not delay the response indefinitely or accumulate sockets across repeated requests.
Driver/server timeouts are additional guards bounded by remaining time, not separate additive budgets.
The external ≤5,000 ms HTTP assertion establishes actual compliance in the local environment.

Compose services are `app` and `db`. `pg_isready` gates initial startup only and does not replace SQL
health evidence. Database loss must leave the app process running; DB recovery needs no app restart.
Expose HTTP on loopback port 3000; no host DB port is needed. Required-value environment interpolation
rejects incomplete Compose configuration with an actionable variable name, never a secret value.
See [data-model.md](data-model.md), [health.openapi.yaml](contracts/health.openapi.yaml) and
[runtime.md](contracts/runtime.md) for exact data, interfaces and command semantics.

### Verification and CI

Tests own a uniquely named Compose project with disposable storage and dynamically published loopback
HTTP port. They never stop the developer's database or use private local configuration. Run fault
scenarios sequentially, bound readiness polling and always clean up owned resources after failure.
Check app container identity and process start time across DB stop/start. A silent TCP fixture checks
nonresponsive dependency behavior. Repeated timeout runs must not leak sockets or crash the app.
The same HTTP assertion oracle must reject a deliberately false healthy response in the unavailable
case; real integration DB loss also makes a hard-coded/cached healthy route fail.

| Criteria | Required evidence / pass condition |
| --- | --- |
| FR-001, FR-006–FR-008; SC-001 | Fresh-checkout configuration, `npm ci`, Compose start, exact healthy response and shutdown with no source edits/chat context. Missing/invalid values never produce full health. |
| FR-002–FR-004; SC-002 | Real HTTP/SQL: 10 healthy → DB stop with app running → 10 exact 503 → DB start/readiness → 10 healthy; unchanged app identity/start time. |
| FR-005; SC-003 | Every healthy/refused/silent-dependency acceptance request yields expected HTTP/body within 5,000 ms measured monotonically. Client timeout fails the test. |
| FR-009; SC-004 | `npm run lint`, `npm run typecheck`, `npm run build`, `npm test`, `npm run verify:startup` all exit zero. False-full-health negative control is rejected. |
| FR-010; SC-005 | GitHub Actions on push and pull_request runs the same five commands; SHA-linked statuses and sanitized output retained, without AI participation. |
| FR-011–FR-012; SC-006 | Committed spec/plan/tasks, task-linked implementation commits, revision-linked decisions/evidence/gaps; implementer and reviewer independently recover status and next action. |
| FR-007, FR-014; SC-007 | Actual diff/dependency/secret review; ignored untracked local env files; no excluded scope or unauthorized promotion. Failures block completion/commits. |
| FR-013–FR-014; SC-008 | Result contains every required metric, reviewed revision, final human decision and next action; critique explicitly not performed when skipped. No subsequent iteration before acceptance. |

CI uses Node 24 and Docker on Linux, installs with `npm ci`, and generates job-local configuration.
Only sanitized summaries are retained with commit SHA and job URL. Do not print env files, resolved
Compose configuration or raw driver errors. Grant read-only repository permissions; no LLM, merge
or repair job. Missing Docker/prerequisites fails rather than silently skipping required checks.

### Handoff and stop conditions

Codex: architect/reviewer; Claude Code: implementer; optional Grok Build: read-only critic.
GitHub Spec Kit and Git retain intent/work state; GitHub Actions is the deterministic verifier.
Next run tasks and analysis, record HUMAN GATE #2 against active artifact revisions and commit the
reviewed planning baseline. No tasks, implementation or experiment-result claims are created now.

Implementation changes must link to task IDs. Evidence records SHA, commands, results and criterion
mapping; convergence compares actual code/diff with committed intent and records gaps or no gaps.
Repairs are human-directed; a second repair cycle requires another explicit decision. The optional
critic receives intent artifacts, diff, safe evidence and convergence outcome without write access.
Final promotion approval identifies the reviewed revision/evidence. Complete all FR-013 measurements,
commit final records after diff/secret checks, then stop. Further iteration waits for human acceptance.

## Complexity Tracking

No constitutional violations or scope exceptions. No ORM, migrations, custom process infrastructure
or product functionality is justified for this foundation slice.
