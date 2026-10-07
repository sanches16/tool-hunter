# Research: PLATFORM-POC-001 — Foundation Health

**Date**: 2026-10-07. Basis: approved [spec.md](spec.md), constitution v1.0.0 and POC scope/exclusions.
Requirement-driven research only; no external feature input, runtime experiments or package installs.

## Runtime and dependencies

- **Decision**: Node 24 LTS, strict TypeScript, Next.js App Router/Node runtime, required React
  packages, direct `pg`, npm lockfile, ESLint and Node built-in tests. PostgreSQL 17 is the chosen
  PoC database major. Pin compatible stable package releases and image digests during implementation.
- **Rationale**: Approved platform scope plus FR-001/FR-009 need only a small web app, SQL and
  independently executable checks. Exact pins and successful install/build are implementation evidence.
- **Alternatives considered**: Other frameworks conflict with source scope; ORM and migration tools
  have no schema requirement; additional test frameworks add dependencies without necessity.

## Per-request evidence

- **Decision**: A fresh short-lived client executes `SELECT 1` and validates the returned value
  on every request. Forced dynamic route, no-store response, no retained health result.
- **Rationale**: FR-002–FR-004 require current operation evidence after prior success and recovery.
  Fresh clients simplify recovery without stale pooled sockets or acquisition queues. No schema needed.
- **Alternatives considered**: TCP/port checks, `pg_isready`, cached/static responses cannot prove SQL.
  Pooling is possible but adds acquisition/stale-client complexity without a load requirement.

## Deadline and cleanup

- **Decision**: One total 4,000 ms monotonic deadline from handler entry covers configuration,
  connection/authentication and query. Bound driver/server guards by remaining time. Reserve 1,000 ms
  for response/transport. On timeout select 503, cancel/destroy transport, clear timers and observe
  late errors; never wait indefinitely for teardown before responding. Late success cannot change failure.
- **Rationale**: FR-005 limits whole handled requests; independent connection/query budgets can exceed
  it. SC-003 needs a silent dependency test. Racing a promise alone leaves live work and sockets;
  repeated-failure resource checks validate actual cleanup for the selected driver release.
- **Alternatives considered**: Connection timeout alone misses hung queries; statement timeout alone
  misses handshake; unbounded retry/cleanup breaks the deadline. No production latency SLA is inferred.

## Configuration and safety

- **Decision**: Require separate POSTGRES_HOST/PORT/DB/USER/PASSWORD values, validate nonempty strings
  and integer port range. No implicit destination or URL fallback. Missing/invalid configuration
  produces 503 in a running app; required-value Compose interpolation may fail startup first.
  Safe example password is empty and replaced locally; do not log private connection details.
- **Rationale**: FR-006 permits actionable startup failure or degraded health. FR-007 requires safe
  templates, ignored local values and secret-free responses/diagnostics. Build needs no database.
- **Alternatives considered**: Defaults risk reaching an unrelated DB; committed usable credentials
  violate the constitution; raw driver messages can disclose private connection information.

## Local lifecycle

- **Decision**: Compose services app/db with Node 24 and PostgreSQL 17; DB readiness gates initial
  startup, but DB loss never stops/restarts the app. Loopback HTTP binding, no host DB port, local named
  volume, isolated disposable test volumes. Docker context excludes env files and local credentials.
- **Rationale**: FR-001/FR-008 require reproducible startup/shutdown; FR-004 and recovery require
  the same live app process. Containerized app unifies startup checks locally and in CI.
- **Alternatives considered**: Host app is viable but needs a second startup lifecycle; whole-stack
  restart cannot prove no-app-restart recovery. Domain migrations/deployment are excluded.

## Deterministic fault validation

- **Decision**: Built-in Node tests own an isolated Compose project and assert real HTTP/SQL through
  ten healthy, ten database-loss and ten recovered requests. Record app identity/start time and every
  elapsed request. Include cold failure, invalid credentials/configuration and a minimal TCP listener
  that never answers PostgreSQL messages. Sequential fault tests always clean up and bound readiness.
  A shared HTTP assertion oracle must reject a deliberately false healthy response for the failure case.
- **Rationale**: SC-002–SC-004 require classification, deadlines and fault-sensitive tests. The actual
  DB-stop test fails hard-coded/cached healthy implementations; oracle negative control verifies the
  assertions are active. HTTP client timeout above five seconds exposes rather than hides deadline failure.
- **Alternatives considered**: Mock-only checks do not prove SQL. Manual curl lacks complete repeatable
  evidence. Refused connections do not exercise silent dependencies. Proxy libraries are unnecessary.

## CI and handoff

- **Decision**: GitHub Actions push/pull_request runs identical core commands with Node 24/Docker,
  job-local values and sanitized SHA-linked summaries. Git records task links, approvals, convergence
  and FR-013 metrics. Native CLIs and Spec Kit provide roles; optional critique is read-only.
- **Rationale**: FR-010–FR-014 require independent evidence and resumability without chat history,
  human promotion and existing tooling. Planning/checklist outputs cannot prove runtime completion.
- **Alternatives considered**: Agent-judged tests, custom schedulers/state stores, autonomous repair
  and merge are forbidden. Optional critique may be omitted only with a not-performed record.

## Resolution

All design unknowns are resolved. No spec amendment, constitutional waiver or scope exception.
Exact version pins/digests and observed pass results are future implementation outputs, subject to
HUMAN GATE #2 approval of the active plan and tasks before work starts.
