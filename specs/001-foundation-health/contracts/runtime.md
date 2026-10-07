# Runtime and Verification Contract

This is a planned interface, implemented only after HUMAN GATE #2.
Basis: [spec.md](../spec.md) FR-001–FR-014 and constitution v1.0.0.

## Configuration

Require `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`.
No implicit host, database, role or password fallback. Validate nonempty strings and numeric port
1–65535. `.env.example` provides `db`, `5432`, `foundation`, `foundation` and an empty password,
respectively. A human supplies a locally generated password. These named examples are non-sensitive
identifiers, not credentials. No `NEXT_PUBLIC_` database variables or credential-bearing connection URL.

Compose services `app` and `db` use the same local DB/user/password values. The application target
is service `db`, port 5432. Required interpolation rejects missing configuration with the variable
name only. App runtime configuration errors return the exact 503 contract without raw error text.
Allow direct app execution with valid syntax but unreachable DB for cold-failure tests. Build must
succeed without database configuration or connection. No application startup query or cached state
substitutes for the per-request operation.

Changing initialization credentials on an existing PostgreSQL volume does not redefine that volume's
role. Use the original local values for ordinary stop/start; use isolated disposable volumes for
configuration-failure tests. No data migration or durability promise is part of this PoC.

## Compose interface

| Command | Expected result |
| --- | --- |
| `docker compose up -d --build --wait --wait-timeout 120` | Build/start app and db; db readiness check succeeds; app listening on loopback port 3000. Nonzero on startup/readiness failure. |
| `docker compose stop db` | DB stopped, app process remains running and health returns 503. |
| `docker compose start db` | Same app process can observe successful fresh DB operations once DB is genuinely ready. |
| `docker compose down` | Owned app/db containers and network stop; local volume retained. |

Plain `docker compose up -d` also starts the configured services once the image is built.
Do not use restart cascades or bind the developer DB port publicly. Startup healthchecks and bounded
polling are independent of the per-request deadline. Health is an observation, not future availability.

## npm scripts (required implementation interface)

| Command | Meaning / pass condition |
| --- | --- |
| `npm ci` | Install exactly the committed lockfile; mismatch/missing lockfile fails. |
| `npm run dev` | Start optional host development app; use explicitly appropriate connection values, no hidden default. |
| `npm start` | Start built app in production mode, without blocking on DB availability. |
| `npm run lint` | ESLint source/configuration/tests; zero exit on no violations. |
| `npm run typecheck` | TypeScript no-emit strict check. Prepare framework-generated route types if needed so fresh checkout does not depend on earlier build. |
| `npm run build` | Production Next.js build without live DB or secrets; zero exit on success. |
| `npm test` | Node runner owns isolated real app/DB fixtures and all health/fault assertions below; zero only when all pass. |
| `npm run verify:startup` | Isolated Compose startup, exact healthy HTTP/JSON check and shutdown with cleanup; zero only on success. |

Integration/startup commands require Docker/Compose and do not skip checks when unavailable.
They generate ephemeral local test credentials without printing them, use unique project names,
disposable storage and dynamically allocated loopback HTTP ports. Resolve actual mapped port
through Compose. Always clean up only owned resources, including after an assertion fails.

## Required test assertions

- Compare status code, exact three-field JSON and `Cache-Control: no-store` for every response.
- Healthy requests require actual PostgreSQL `SELECT 1`; DB stop must make an always-healthy route fail.
- Ten healthy → ten after DB loss → ten after restored DB, with unchanged app container ID and process
  start time. Readiness polling is bounded and precedes acceptance batches; it cannot replace assertions.
- Every timed healthy/refused/silent dependency request finishes ≤5,000 ms using monotonic HTTP timing.
  HTTP client watchdog exceeds five seconds (for example six); timeout, disconnect or missing body fails.
- Cold unreachable DB, invalid credentials, missing/invalid configuration and silent TCP listener
  yield exact 503. Add focused helper checks where a test-only client connects successfully but
  rejects or never completes the SQL operation: classify unavailable within the same total budget
  and reclaim its resources. Those checks complement the mandatory real HTTP/PostgreSQL suite.
  Test substitutions must never become an application runtime bypass or environment switch.
- Repeated deadline failures do not grow owned open sockets indefinitely, trigger unhandled errors or
  crash the app; cleanup must release each client's transport within a documented bounded grace period.
- Feed deliberately false HTTP 200/full-health data into the same failure assertion oracle and
  require assertion failure. Do not invert the real failure-scenario result to make a faulty route pass.

## CI and evidence

GitHub Actions runs on `push` and `pull_request`, with read-only repository permissions, Node 24,
Docker/Compose and the same install/five verification commands. Its isolated fixtures use job-local
values; no personal or deployed DB connection is needed. Nonzero checks fail the job. Retain sanitized
check/test summaries tied to commit SHA/job URL, including failed runs. No agent interprets pass/fail.

Evidence records revision, commands, tool versions, expected and observed results and FR/SC mapping.
Never upload env files, private connection values, raw driver diagnostics, cookies or tokens.
Before commits inspect diff and staged content for secrets; no generated private env/image state
enters Git. Human gate, task links, convergence and experiment ratings are reviewable Git records,
not hidden state. No command above authorizes repair, merge or further iteration.
