# Quickstart and Validation: PLATFORM-POC-001

**Status**: Planned commands for the future approved implementation. The application, npm scripts,
Compose files and CI do not exist yet; these commands were not run during planning.
HUMAN GATE #2 must approve active plan/tasks before implementation.
See [runtime contract](contracts/runtime.md), [HTTP contract](contracts/health.openapi.yaml)
and [data model](data-model.md) for exact interfaces and record fields.

## Prerequisites

A fresh checkout of the private canonical repository on `poc/platform-poc-001`, Node.js 24 LTS,
the npm version recorded with the lockfile, Docker Engine/Desktop running, Docker Compose v2,
Git, curl and Python 3. Port 3000 must be available. CI uses the same core Node/Docker prerequisites.
No agent CLI is required to run application verification. Spec Kit/native CLIs are needed only for
later role-specific process stages. Do not reinstall process tooling or reconstruct the repository.

Record `git rev-parse HEAD`, `node --version`, `npm --version`, `docker --version`,
`docker compose version` and `git status --short` with the checked revision. Verify active approvals
cover that revision before implementing. Do not record private environment values.

## Fresh-checkout setup and startup (FR-001, FR-006–FR-008; SC-001)

Run from repository root after implementation is approved and present:

```bash
npm ci
cp -n .env.example .env
python3 - <<'CONFIG'
from pathlib import Path
import secrets
path = Path('.env')
value = path.read_text()
assert value.count('POSTGRES_PASSWORD=\n') == 1, 'Expected one empty password example'
path.write_text(value.replace('POSTGRES_PASSWORD=\n', 'POSTGRES_PASSWORD=' + secrets.token_hex(24) + '\n'))
path.chmod(0o600)
CONFIG
git check-ignore .env
git ls-files -- .env
docker compose up -d --build --wait --wait-timeout 120
curl -sS --max-time 6 -i http://localhost:3000/api/health
```

Use a fresh copy of the safe example; never overwrite an existing local `.env` with private values.
The Python snippet is local configuration setup only, not application implementation. `.env.example`
contains one empty `POSTGRES_PASSWORD=` line. Other example values select `db:5432`, database/user
`foundation`. A generated password exists only in the ignored local file, not command output.
`git check-ignore` prints `.env`; `git ls-files` prints nothing. Docker starts `app` and `db`.
Healthy response: HTTP 200, `Content-Type: application/json`, `Cache-Control: no-store`, exactly
`{"status":"ok","application":"ok","database":"ok"}` (JSON key order is irrelevant).
Startup failure must be actionable without printing private values. No source edit or chat history.

## Manual dependency-loss and recovery check (FR-002–FR-005)

Keep the application running throughout. Record container ID and start timestamp before stopping DB:

```bash
docker compose ps -q app
docker inspect --format '{{.State.StartedAt}}' "$(docker compose ps -q app)"
docker compose stop db
curl -sS --max-time 6 -i http://localhost:3000/api/health
docker compose start db
```

After stop completes, expect HTTP 503 with exactly
`{"status":"degraded","application":"ok","database":"unavailable"}`, no-store, within five seconds.
`curl -f` is deliberately omitted here because 503 is the expected response.
Once DB readiness has returned, repeat the request and the two app identity commands: expect HTTP
200 and unchanged app identity/start time. Do not restart/recreate `app` to obtain recovery.
A successful operation observes current availability; it does not promise future uptime.

## Core deterministic verification (FR-009–FR-010; SC-002–SC-005)

```bash
npm run lint
npm run typecheck
npm run build
npm test
npm run verify:startup
```

All five must exit zero; record exit codes and safe summaries at the checked SHA. Typecheck prepares
any required generated types independently; build does not connect to the DB. Tests/startup use their
own isolated Compose projects, dynamically allocated loopback ports and disposable credentials/data.
They clean up even on failure and never stop the developer stack. Missing Docker fails, never skips.

`npm test` must deterministically prove:

1. Ten exact healthy responses against actual PostgreSQL.
2. Stop DB while the same app process remains running; ten exact unavailable responses with zero
   full-health results, each within five seconds.
3. Start DB, wait for genuine readiness with a finite deadline; ten exact healthy responses without
   app restart. App identity and process start time remain unchanged across this sequence.
4. First-request unreachable DB, invalid credentials, missing/invalid configuration and a test-only
   TCP listener that accepts connections but never answers all produce the exact unavailable result.
   Isolated app variants allow failure before any successful request and bypass initial DB-ready
   startup ordering only in test configuration.
5. Focused helper checks cover query failure/hang after connection succeeds. Repeated timeouts reclaim
   client resources within bounded cleanup grace, cause no unhandled errors and leave the app alive.
6. Every healthy/refused/silent-dependency acceptance request uses monotonic elapsed timing and
   asserts ≤5,000 ms. A six-second client watchdog detects failures; an abort is not a passing 503.
7. The same failure assertion oracle rejects an intentionally false HTTP 200/full-health fixture.
   The mandatory real DB-stop scenario also fails if the implemented endpoint lies or caches success.
   No production health-bypass setting may be introduced for tests.

`npm run verify:startup` independently builds/starts the isolated Compose foundation, bounds readiness,
checks exact healthy HTTP/JSON and stops all owned services. Its cleanup and status are part of the
pass condition. Manual curl is supplementary; automated assertions are the completion evidence.

## CI parity

GitHub Actions must run on push and pull_request using Node 24 and Docker/Compose:
`npm ci`, then the same five commands above. Use generated job-local values, read-only repository
permissions and no agent. A deliberate false-full-health implementation must fail the unavailable
integration assertion and therefore fail CI. Publish SHA-linked job status and sanitized summaries,
including failed checks; never upload environment files or private driver output.

## Shutdown

```bash
docker compose down
```

App/DB containers and network stop. The local named volume remains for ordinary reuse; tests remove
only their own disposable volumes. With the application stopped no health HTTP response is available,
which means application availability has not been established. No deployment or durability guarantee.

## Evidence, handoff and human decisions (FR-011–FR-014; SC-006–SC-008)

Retain criterion-linked evidence: checked SHA, commands, prerequisites/tool versions, expected and
observed results, safe outputs, CI URL/status, gaps and next action. Do not label runtime criteria
complete until required evidence passes. Inspect actual diff and staged files for secrets and scope
violations before committing; local env files and secret values remain untracked. Inspect dependencies
for prohibited tooling. Failing scope/secret checks block completion/commit.

An implementer and reviewer must each locate the approved spec/constitution, plan/tasks, human gate
records, task-linked changes, evidence, gaps and next action without chat. Generate tasks and run
analysis separately; HUMAN GATE #2 must approve current revisions, then commit the planning baseline
before Claude implements. Codex convergence records gaps or evidence of none against committed
artifacts. Any repair is human-directed; a second cycle requires a new explicit decision.

Optional Grok critique reads intent artifacts, diff, evidence and convergence without source changes;
otherwise record `not performed`. Final human promotion approval identifies reviewed revision and
evidence. Complete `docs/poc/PLATFORM-POC-001-RESULT.md` with every FR-013 metric and 1–5 human rating
listed in [data-model.md](data-model.md). Record accept/request changes/abort and process suitability.
After final records/verification/reviews are committed, stop; no further iteration without explicit
human acceptance. Passing checks do not authorize merge.
