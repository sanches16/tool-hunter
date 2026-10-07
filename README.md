# tool-hunter — foundation health (PLATFORM-POC-001)

A minimal Next.js application with one endpoint, `GET /api/health`, that reports whether the
application is running and whether it can complete a fresh PostgreSQL operation (`SELECT 1`) right
now. The application and PostgreSQL 17 run locally through Docker Compose.

This README covers local setup, the manual health/dependency-loss checks and the verification
commands. Exact interfaces live in
[`specs/001-foundation-health/contracts/runtime.md`](specs/001-foundation-health/contracts/runtime.md)
and [`specs/001-foundation-health/quickstart.md`](specs/001-foundation-health/quickstart.md).
Everything below works from a fresh checkout without source edits or prior chat context.

> **Current status:** the application, Dockerfile and Compose stack, the real Docker/Compose
> integration suite (`npm test`), the isolated startup verifier (`npm run verify:startup`) and
> GitHub Actions CI are implemented — see [Verification commands](#verification-commands). This is
> work in progress on the PoC branch; it does not by itself constitute final PoC acceptance.

## Prerequisites

- Node.js 24 (`package.json` requires `>=24 <25`) and the npm bundled with it
- Docker Engine or Docker Desktop, running
- Docker Compose v2 (`docker compose`)
- Git, curl and Python 3
- Local port 3000 free (the app is published on `127.0.0.1:3000` only)

No agent CLI is needed to run or verify the application.

## Setup

Run every command from the repository root.

### 1. Install dependencies

```bash
npm ci
```

`npm ci` installs exactly the committed `package-lock.json` and fails if it is missing or out of sync.

### 2. Create the local `.env` without overwriting an existing one

```bash
test -e .env || cp .env.example .env
```

This copies the safe example only when no `.env` exists (same effect as `cp -n`). Never overwrite an
existing local `.env`: it may hold the password that an existing database volume was initialized
with (see [Existing database volume](#existing-database-volume-and-credentials)).

`.env.example` sets `POSTGRES_HOST=db`, `POSTGRES_PORT=5432`, `POSTGRES_DB=foundation`,
`POSTGRES_USER=foundation` and an empty `POSTGRES_PASSWORD=`. These names are non-sensitive
identifiers. Docker Compose reads `.env` automatically; `compose.yaml` always points the app at
service `db`, port 5432.

### 3. Generate a local password (printed nowhere)

```bash
python3 - <<'CONFIG'
from pathlib import Path
import secrets
path = Path('.env')
value = path.read_text()
assert value.count('POSTGRES_PASSWORD=\n') == 1, 'Expected one empty password example'
path.write_text(value.replace('POSTGRES_PASSWORD=\n', 'POSTGRES_PASSWORD=' + secrets.token_hex(24) + '\n'))
path.chmod(0o600)
CONFIG
```

The snippet fills the single empty `POSTGRES_PASSWORD=` line with a random value, restricts the file
to your user and prints nothing on success. If `.env` already has a password, the assertion fails
with `Expected one empty password example` and nothing is changed — keep the existing value.

Do not display the password: avoid `cat .env`, and avoid `docker compose config`, which prints
interpolated values. Never commit `.env` or paste its contents anywhere.

### 4. Confirm `.env` is ignored and untracked

```bash
git check-ignore .env
git ls-files -- .env
```

Expected: `git check-ignore` prints `.env`; `git ls-files` prints nothing. If either differs, stop
and fix that before continuing.

### 5. Build and start the stack

```bash
docker compose up -d --build --wait --wait-timeout 120
```

This builds the app image, starts `db` and `app`, and waits (at most 120 s) until both report
healthy. It exits nonzero if startup or readiness fails. If a required variable is missing or empty,
Compose stops with an error naming only that variable (for example `POSTGRES_PASSWORD`), never a
value.

Once the image has been built, a plain start is enough:

```bash
docker compose up -d
```

The database has no host port; it is reachable only on the Compose network. The app's container
healthcheck checks only that the HTTP server answers, not the database.

## Health check

```bash
curl -sS --max-time 6 -i http://127.0.0.1:3000/api/health
```

Healthy expectation:

- HTTP `200`
- `Content-Type: application/json`
- `Cache-Control: no-store`
- body exactly `{"status":"ok","application":"ok","database":"ok"}` (key order is irrelevant)

Every request runs a fresh database operation with a total budget of 4 s, so the response arrives
within 5 s. A result describes availability at that moment only; it does not promise future uptime.

## Manual dependency-loss and recovery check

Keep the application running throughout; never restart or recreate `app` to obtain recovery.

### 1. Record the app's identity before the database loss

```bash
APP_ID_BEFORE="$(docker compose ps -q app)"
APP_STARTED_BEFORE="$(docker inspect --format '{{.State.StartedAt}}' "$APP_ID_BEFORE")"
echo "$APP_ID_BEFORE $APP_STARTED_BEFORE"
```

### 2. Stop only the database

```bash
docker compose stop db
curl -sS --max-time 6 -i http://127.0.0.1:3000/api/health
```

After `docker compose stop db` completes, expect within 5 s:

- HTTP `503`
- `Cache-Control: no-store`
- body exactly `{"status":"degraded","application":"ok","database":"unavailable"}`

The app container keeps running (`docker compose ps app` still shows it up). `curl -f` is
deliberately not used: 503 is the expected response here.

### 3. Start the database and wait for readiness (bounded)

```bash
docker compose start db
for attempt in $(seq 1 30); do
  status="$(docker inspect --format '{{.State.Health.Status}}' "$(docker compose ps -q db)")"
  [ "$status" = healthy ] && break
  sleep 2
done
echo "db health: $status"
```

The loop gives up after about 60 s. Continue only when it prints `db health: healthy`; otherwise
inspect `docker compose ps` and `docker compose logs db`.

### 4. Confirm recovery with the same app process

```bash
curl -sS --max-time 6 -i http://127.0.0.1:3000/api/health
APP_ID_AFTER="$(docker compose ps -q app)"
APP_STARTED_AFTER="$(docker inspect --format '{{.State.StartedAt}}' "$APP_ID_AFTER")"
echo "$APP_ID_AFTER $APP_STARTED_AFTER"
[ "$APP_ID_BEFORE" = "$APP_ID_AFTER" ] && [ "$APP_STARTED_BEFORE" = "$APP_STARTED_AFTER" ] \
  && echo "same app container and start time" || echo "APP WAS RESTARTED OR RECREATED"
```

Expect the exact healthy response again (HTTP `200`, `Cache-Control: no-store`,
`{"status":"ok","application":"ok","database":"ok"}`) and `same app container and start time`.
Recovery comes from the next fresh database operation, not from an app restart: `compose.yaml` uses
`restart: "no"` and `depends_on` with `restart: false`, so DB stop/start never touches `app`.

### 5. Stopped application gives no HTTP response

```bash
docker compose stop app
curl -sS --max-time 6 -i http://127.0.0.1:3000/api/health
```

With the app stopped, curl reports a connection error and there is **no HTTP response at all** —
not a 503. No response means application availability has not been established. Bring it back with
`docker compose start app` (or `docker compose up -d`) if you want to continue.

## Shutdown

```bash
docker compose down
```

Stops and removes the `app` and `db` containers and the Compose network. The named volume `db-data`
is **retained**, so the next `docker compose up -d` reuses the existing database.

### Existing database volume and credentials

PostgreSQL applies `POSTGRES_DB`, `POSTGRES_USER` and `POSTGRES_PASSWORD` only when it initializes
an empty volume. Once `db-data` exists, it keeps its original credentials: changing or regenerating
the password in `.env` does not change the role, and the app will then report
`database: "unavailable"` (HTTP 503) because it can no longer authenticate. Keep using the original
local `.env` for ordinary stop/start. If you deliberately want to start over with new credentials,
remove the volume explicitly with `docker compose down -v` — this permanently deletes the local
database data. This PoC makes no data migration or durability promise.

## Verification commands

```bash
npm run lint
npm run typecheck
npm run build
npm test
npm run verify:startup
```

| Command | What it does today |
| --- | --- |
| `npm run lint` | ESLint over the repository. |
| `npm run typecheck` | `next typegen` then `tsc --noEmit` (strict); works on a fresh checkout without a prior build. |
| `npm run build` | Production Next.js build; needs no database configuration or connection. |
| `npm test` | Runs `tests/integration/health.test.mjs`: focused code-level checks (configuration validation, the database probe through an injected test client, self-tests of the shared HTTP response assertions) **and** real Docker/Compose scenarios with the production image in isolated Compose projects (see below). Requires Docker and Compose; takes a few minutes. |
| `npm run verify:startup` | Runs `scripts/verify-startup.mjs`: an independent, isolated startup proof of the production image with PostgreSQL 17 (see below). Requires Docker and Compose. |

### Implemented verification coverage

`npm test` real Docker/Compose scenarios (from `tests/compose.test.yaml`), each in its own isolated
Compose project with ≤5 s timing on every request:

- database loss and recovery: 10 healthy → 10 after DB stop (database unavailable) → 10 after DB
  recovery, with unchanged app identity;
- silent PostgreSQL listener: requests stay bounded and sockets are cleaned up;
- missing, empty and invalid runtime configuration;
- authentication failure (invalid credentials);
- cold-refused database target.

`npm run verify:startup` uses a unique Compose project with generated credentials, gives the
database no host port, publishes the app only on `127.0.0.1` with a dynamic port, performs one exact
healthy check (HTTP 200, `Cache-Control: no-store`, ok/ok/ok body, ≤5,000 ms) and always cleans up
its project.

CI (`.github/workflows/ci.yml`) runs on `push` and `pull_request` with read-only permissions:
`npm ci`, then the five commands above.

The manual checks above are supplementary, not completion evidence. All five commands must exit
zero before the runtime criteria can be considered verified.
