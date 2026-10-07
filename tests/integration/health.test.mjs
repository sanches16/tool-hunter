import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { randomBytes } from "node:crypto";
import { afterEach, beforeEach, describe, test } from "node:test";
import { performance } from "node:perf_hooks";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";

import {
  PROBE_BUDGET_MS,
  probeDatabase,
  readDatabaseConfig,
} from "../../src/lib/database-health.ts";
import {
  HEALTHY_BODY,
  MAX_RESPONSE_MS,
  UNAVAILABLE_BODY,
  WATCHDOG_MS,
  assertHealthyResponse,
  assertUnavailableResponse,
  assertWithinDeadline,
  measureRequest,
} from "../helpers/health-assertions.mjs";

// Focused, deterministic checks of the Iteration B probe through its code-level client injection
// interface (T011) and self-tests of the shared HTTP assertions (T006) use no Docker, PostgreSQL,
// HTTP server or network. The last suite (T008/T009 subset) runs the real 10 healthy -> 10
// database-loss -> 10 recovery lifecycle against the production image and PostgreSQL 17.

const VALID_ENV = Object.freeze({
  POSTGRES_HOST: "db.internal",
  POSTGRES_PORT: "5432",
  POSTGRES_DB: "toolhunter",
  POSTGRES_USER: "probe-user",
  POSTGRES_PASSWORD: "test-only-password",
});
const ENV_KEYS = Object.keys(VALID_ENV);

/** Short test-only budget; the production PROBE_BUDGET_MS is never waited for. */
const TEST_BUDGET_MS = 60;

/** Generous upper bound for a short-budget probe to settle, tolerant of scheduler jitter. */
const SETTLE_LIMIT_MS = 1_000;

const never = () => new Promise(() => {});

function testDeadline(budgetMs = TEST_BUDGET_MS) {
  const expiresAt = performance.now() + budgetMs;
  return { remaining: () => expiresAt - performance.now() };
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

/** Fake ProbeClient/ProbeClientFactory recording every call. Behaviors default to healthy. */
function fakeClient({
  connect = () => Promise.resolve(),
  query = () => Promise.resolve([{ ok: 1 }]),
  close = () => Promise.resolve(),
  destroy = () => {},
  factory,
} = {}) {
  const calls = { factory: [], connect: 0, query: [], close: 0, destroy: 0 };
  const client = {
    connect: () => {
      calls.connect += 1;
      return connect();
    },
    query: (sql, timeoutMs) => {
      calls.query.push({ sql, timeoutMs });
      return query();
    },
    close: () => {
      calls.close += 1;
      return close();
    },
    destroy: () => {
      calls.destroy += 1;
      destroy();
    },
  };
  const createClient = (config, budgetMs) => {
    calls.factory.push({ config, budgetMs });
    if (factory) {
      factory();
    }
    return client;
  };
  return { calls, createClient };
}

async function timedProbe(createClient, deadline = testDeadline()) {
  const startedAt = performance.now();
  const healthy = await probeDatabase(deadline, createClient);
  return { healthy, elapsedMs: performance.now() - startedAt };
}

/** Lets already-scheduled microtasks and immediate callbacks (late outcomes, release) run. */
async function flush() {
  await delay(0);
  await new Promise((resolve) => setImmediate(resolve));
}

function assertDestroyedNotClosed(calls) {
  assert.equal(calls.destroy, 1, "failed observation must destroy the client exactly once");
  assert.equal(calls.close, 0, "failed observation must not close gracefully");
}

describe("readDatabaseConfig", () => {
  test("1. accepts a complete valid configuration without altering values", () => {
    const env = { ...VALID_ENV, POSTGRES_PASSWORD: " p@ss word:/?# " };
    assert.deepEqual(readDatabaseConfig(env), {
      host: "db.internal",
      port: 5432,
      database: "toolhunter",
      user: "probe-user",
      password: " p@ss word:/?# ",
    });
    assert.equal(readDatabaseConfig({ ...VALID_ENV, POSTGRES_PORT: "1" })?.port, 1);
    assert.equal(readDatabaseConfig({ ...VALID_ENV, POSTGRES_PORT: "65535" })?.port, 65_535);
  });

  test("2. missing required configuration is rejected", () => {
    for (const key of ENV_KEYS) {
      const env = { ...VALID_ENV };
      delete env[key];
      assert.equal(readDatabaseConfig(env), null, `missing ${key} must be rejected`);
    }
    assert.equal(readDatabaseConfig({}), null);
  });

  test("3. empty required configuration is rejected", () => {
    for (const key of ENV_KEYS) {
      assert.equal(readDatabaseConfig({ ...VALID_ENV, [key]: "" }), null, `empty ${key}`);
    }
  });

  test("4. invalid POSTGRES_PORT is rejected", () => {
    const invalid = [
      "0",
      "65536",
      "-1",
      "+5432",
      "abc",
      "54a2",
      "54.32",
      "1e3",
      "0x10",
      " 5432",
      "5432 ",
      "99999999999999999999",
    ];
    for (const port of invalid) {
      assert.equal(
        readDatabaseConfig({ ...VALID_ENV, POSTGRES_PORT: port }),
        null,
        `port ${JSON.stringify(port)}`,
      );
    }
  });
});

describe("probeDatabase with injected test client", () => {
  let savedEnv;

  beforeEach(() => {
    savedEnv = Object.fromEntries(ENV_KEYS.map((key) => [key, process.env[key]]));
    Object.assign(process.env, VALID_ENV);
  });

  afterEach(() => {
    for (const key of ENV_KEYS) {
      if (savedEnv[key] === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = savedEnv[key];
      }
    }
  });

  test("production budget is unchanged and is not used by these tests", () => {
    assert.equal(PROBE_BUDGET_MS, 4_000);
    assert.ok(TEST_BUDGET_MS < PROBE_BUDGET_MS);
  });

  test("2/3/4. missing, empty or invalid configuration -> unavailable without a client", async () => {
    const cases = [
      ["missing POSTGRES_HOST", "POSTGRES_HOST", undefined],
      ["missing POSTGRES_PASSWORD", "POSTGRES_PASSWORD", undefined],
      ["empty POSTGRES_DB", "POSTGRES_DB", ""],
      ["empty POSTGRES_USER", "POSTGRES_USER", ""],
      ["invalid POSTGRES_PORT", "POSTGRES_PORT", "not-a-port"],
      ["out-of-range POSTGRES_PORT", "POSTGRES_PORT", "70000"],
    ];
    for (const [label, key, value] of cases) {
      Object.assign(process.env, VALID_ENV);
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
      const { calls, createClient } = fakeClient();
      assert.equal(await probeDatabase(testDeadline(), createClient), false, label);
      assert.equal(calls.factory.length, 0, `${label}: no client may be created`);
    }
  });

  test("5/12. successful connect + [{ ok: 1 }] -> healthy, then graceful close()", async () => {
    const { calls, createClient } = fakeClient();
    const { healthy, elapsedMs } = await timedProbe(createClient);

    assert.equal(healthy, true);
    assert.ok(elapsedMs < SETTLE_LIMIT_MS);
    assert.equal(calls.factory.length, 1);
    assert.deepEqual(calls.factory[0].config, readDatabaseConfig(VALID_ENV));
    assert.ok(calls.factory[0].budgetMs > 0 && calls.factory[0].budgetMs <= TEST_BUDGET_MS);
    assert.equal(calls.connect, 1);
    assert.equal(calls.query.length, 1);
    assert.equal(calls.query[0].sql, "SELECT 1 AS ok");
    assert.ok(calls.query[0].timeoutMs > 0 && calls.query[0].timeoutMs <= TEST_BUDGET_MS);

    await flush();
    assert.equal(calls.close, 1, "healthy observation must close gracefully");
    assert.equal(calls.destroy, 0, "a promptly closed healthy client must not be destroyed");
  });

  test("12. healthy close() that never settles is force-destroyed after the grace period", async () => {
    const { calls, createClient } = fakeClient({ close: never });
    assert.equal(await probeDatabase(testDeadline(), createClient), true);
    assert.equal(calls.close, 1);
    assert.equal(calls.destroy, 0);

    const waitUntil = performance.now() + 3_000;
    while (calls.destroy === 0 && performance.now() < waitUntil) {
      await delay(50);
    }
    assert.equal(calls.destroy, 1, "stalled graceful close must be reclaimed by destroy()");
  });

  test("12. healthy close() rejection or synchronous throw falls back to destroy()", async () => {
    for (const close of [
      () => Promise.reject(new Error("close failed")),
      () => {
        throw new Error("close threw");
      },
    ]) {
      const { calls, createClient } = fakeClient({ close });
      assert.equal(await probeDatabase(testDeadline(), createClient), true);
      await flush();
      assert.equal(calls.close, 1);
      assert.equal(calls.destroy, 1);
    }
  });

  test("6/11. incorrect SQL result -> unavailable and destroy()", async () => {
    const wrongResults = [
      [],
      [{ ok: 1 }, { ok: 1 }],
      [{ ok: "1" }],
      [{ ok: true }],
      [{ ok: 2 }],
      [{ ok: 1, extra: 1 }],
      [{ other: 1 }],
      [{}],
      [null],
      [[1]],
      null,
      undefined,
      "1",
      { ok: 1 },
    ];
    for (const rows of wrongResults) {
      const { calls, createClient } = fakeClient({ query: () => Promise.resolve(rows) });
      assert.equal(
        await probeDatabase(testDeadline(), createClient),
        false,
        `result ${JSON.stringify(rows)} must be unavailable`,
      );
      await flush();
      assertDestroyedNotClosed(calls);
    }
  });

  test("7/11. connect rejection -> unavailable and destroy(), no query", async () => {
    const { calls, createClient } = fakeClient({
      connect: () => Promise.reject(new Error("ECONNREFUSED db.internal:5432")),
    });
    assert.equal(await probeDatabase(testDeadline(), createClient), false);
    await flush();
    assert.equal(calls.query.length, 0);
    assertDestroyedNotClosed(calls);
  });

  test("8/11. successful connect followed by query rejection -> unavailable and destroy()", async () => {
    const { calls, createClient } = fakeClient({
      query: () => Promise.reject(new Error("relation does not exist")),
    });
    assert.equal(await probeDatabase(testDeadline(), createClient), false);
    await flush();
    assert.equal(calls.connect, 1);
    assert.equal(calls.query.length, 1);
    assertDestroyedNotClosed(calls);
  });

  test("9/11. never-resolving query -> deadline -> unavailable and destroy()", async () => {
    const { calls, createClient } = fakeClient({ query: never });
    const { healthy, elapsedMs } = await timedProbe(createClient);

    assert.equal(healthy, false);
    assert.ok(elapsedMs >= TEST_BUDGET_MS - 5, "must not fail before the deadline");
    assert.ok(elapsedMs < SETTLE_LIMIT_MS, "must fail at the test deadline");
    await flush();
    assertDestroyedNotClosed(calls);
  });

  test("9/11. never-resolving connect -> deadline -> unavailable and destroy()", async () => {
    const { calls, createClient } = fakeClient({ connect: never });
    const { healthy, elapsedMs } = await timedProbe(createClient);

    assert.equal(healthy, false);
    assert.ok(elapsedMs < SETTLE_LIMIT_MS);
    await flush();
    assert.equal(calls.query.length, 0);
    assertDestroyedNotClosed(calls);
  });

  test("9. connect time and query time share one deadline", async () => {
    const budgetMs = 200;
    const connectMs = 150;
    const { calls, createClient } = fakeClient({
      connect: () => delay(connectMs),
      query: never,
    });
    const { healthy, elapsedMs } = await timedProbe(createClient, testDeadline(budgetMs));

    assert.equal(healthy, false);
    assert.equal(calls.query.length, 1);
    assert.ok(
      calls.query[0].timeoutMs <= budgetMs - connectMs + 5,
      "query timeout must be the remaining shared budget, not a fresh one",
    );
    assert.ok(
      elapsedMs < budgetMs + connectMs - 20,
      "query must not receive a fresh budget after connect",
    );
    await flush();
    assertDestroyedNotClosed(calls);
  });

  test("9. an already expired deadline -> unavailable without a client", async () => {
    const { calls, createClient } = fakeClient();
    assert.equal(await probeDatabase({ remaining: () => 0 }, createClient), false);
    assert.equal(calls.factory.length, 0);
  });

  test("10. late query success after the deadline does not turn unavailable into healthy", async () => {
    const late = deferred();
    const { calls, createClient } = fakeClient({ query: () => late.promise });
    const probe = probeDatabase(testDeadline(), createClient);

    assert.equal(await probe, false);
    late.resolve([{ ok: 1 }]);
    await flush();

    assert.equal(await probe, false, "outcome must stay unavailable");
    assertDestroyedNotClosed(calls);
  });

  test("10. late connect success after the deadline issues no query and stays unavailable", async () => {
    const late = deferred();
    const { calls, createClient } = fakeClient({ connect: () => late.promise });
    const probe = probeDatabase(testDeadline(), createClient);

    assert.equal(await probe, false);
    late.resolve();
    await flush();

    assert.equal(await probe, false);
    assert.equal(calls.query.length, 0, "no query may run after the deadline");
    assertDestroyedNotClosed(calls);
  });

  test("11. failure paths destroy() exactly once even when destroy() throws", async () => {
    const { calls, createClient } = fakeClient({
      query: () => Promise.reject(new Error("boom")),
      destroy: () => {
        throw new Error("destroy failed");
      },
    });
    assert.equal(await probeDatabase(testDeadline(), createClient), false);
    await flush();
    assertDestroyedNotClosed(calls);
  });

  test("13. driver errors never escape as rejections or unhandled errors", async () => {
    const escaped = [];
    const onEscape = (error) => escaped.push(error);
    process.on("unhandledRejection", onEscape);
    process.on("uncaughtException", onEscape);

    try {
      const lateRejection = deferred();
      const thrower = (error) => () => {
        throw error;
      };
      const scenarios = [
        { factory: thrower(new Error("factory threw")) },
        { connect: thrower(new Error("connect threw synchronously")) },
        { connect: () => Promise.reject("non-error rejection") },
        { query: thrower(new TypeError("query threw synchronously")) },
        { query: () => Promise.reject(undefined) },
        { query: () => lateRejection.promise },
        {
          query: () => Promise.reject(new Error("query failed")),
          destroy: thrower(new Error("destroy failed")),
        },
        { close: () => Promise.reject(new Error("close failed")) },
      ];

      for (const behavior of scenarios) {
        const { createClient } = fakeClient(behavior);
        const outcome = await probeDatabase(testDeadline(), createClient).then(
          (healthy) => ({ healthy }),
          () => ({ rejected: true }),
        );
        assert.equal(outcome.rejected, undefined, "probeDatabase must never reject");
        assert.equal(typeof outcome.healthy, "boolean");
      }

      // A driver error arriving after the deadline outcome must also be absorbed.
      lateRejection.reject(new Error("late driver error"));
      await flush();
      await delay(20);
    } finally {
      process.off("unhandledRejection", onEscape);
      process.off("uncaughtException", onEscape);
    }

    assert.equal(escaped.length, 0, "no driver error may escape");
  });
});

describe("health HTTP assertions (T006 self-tests)", () => {
  const routeResponse = (body, status) =>
    Response.json(body, { status, headers: { "Cache-Control": "no-store" } });

  const responseLike = (overrides = {}) => ({
    status: 503,
    headers: { "Content-Type": "application/json", "Cache-Control": "no-store" },
    body: JSON.stringify(UNAVAILABLE_BODY),
    ...overrides,
  });

  const rejectsSanitized = (promise, secret) =>
    assert.rejects(promise, (error) => {
      assert.ok(error instanceof assert.AssertionError);
      if (secret !== undefined) {
        assert.ok(!error.message.includes(secret), "failure message must be sanitized");
      }
      return true;
    });

  test("14. exact HTTP 200 full health passes and returns the parsed observation", async () => {
    const observation = await assertHealthyResponse(routeResponse(HEALTHY_BODY, 200), {
      elapsedMs: 12,
    });
    assert.equal(observation.httpStatus, 200);
    assert.deepEqual(observation.body, { status: "ok", application: "ok", database: "ok" });
    assert.equal(observation.cacheControl, "no-store");
    assert.match(observation.contentType, /^application\/json/);
    assert.equal(
      observation.summary,
      "HTTP 200 status=ok application=ok database=ok in 12 ms",
    );
  });

  test("15. exact HTTP 503 database-unavailable passes", async () => {
    const observation = await assertUnavailableResponse(routeResponse(UNAVAILABLE_BODY, 503));
    assert.equal(observation.httpStatus, 503);
    assert.deepEqual(observation.body, {
      status: "degraded",
      application: "ok",
      database: "unavailable",
    });

    const plain = await assertUnavailableResponse(responseLike());
    assert.equal(plain.httpStatus, 503);
  });

  test("16. extra JSON fields fail and are not echoed", async () => {
    const secret = "postgres://probe-user:test-only-password@db.internal";
    await rejectsSanitized(
      assertHealthyResponse(routeResponse({ ...HEALTHY_BODY, detail: secret }, 200)),
      secret,
    );
    await rejectsSanitized(
      assertUnavailableResponse(routeResponse({ ...UNAVAILABLE_BODY, error: secret }, 503)),
      secret,
    );
  });

  test("17. incorrect status or body fails", async () => {
    // Wrong HTTP status for an otherwise correct body.
    await rejectsSanitized(assertHealthyResponse(routeResponse(HEALTHY_BODY, 503)));
    await rejectsSanitized(assertUnavailableResponse(routeResponse(UNAVAILABLE_BODY, 200)));
    await rejectsSanitized(assertUnavailableResponse(routeResponse(UNAVAILABLE_BODY, 500)));
    // Wrong, missing or malformed body for a correct status.
    await rejectsSanitized(
      assertHealthyResponse(routeResponse({ ...HEALTHY_BODY, database: "unavailable" }, 200)),
    );
    await rejectsSanitized(
      assertUnavailableResponse(routeResponse({ ...UNAVAILABLE_BODY, status: "ok" }, 503)),
    );
    await rejectsSanitized(
      assertUnavailableResponse(routeResponse({ ...UNAVAILABLE_BODY, application: "down" }, 503)),
    );
    await rejectsSanitized(
      assertHealthyResponse(routeResponse({ status: "ok", application: "ok" }, 200)),
    );
    await rejectsSanitized(assertHealthyResponse(routeResponse([HEALTHY_BODY], 200)));
    await rejectsSanitized(assertUnavailableResponse(responseLike({ body: "not json" })));
    await rejectsSanitized(assertUnavailableResponse(responseLike({ body: "" })));
    await rejectsSanitized(assertUnavailableResponse(responseLike({ body: undefined })));
    await rejectsSanitized(
      assertUnavailableResponse({
        ...responseLike(),
        text: () => Promise.reject(new Error("socket hang up")),
      }),
    );
    await rejectsSanitized(assertUnavailableResponse(undefined));
    // Content type must be JSON.
    await rejectsSanitized(
      assertUnavailableResponse(
        responseLike({ headers: { "Content-Type": "text/plain", "Cache-Control": "no-store" } }),
      ),
    );
  });

  test("18. missing or different Cache-Control fails", async () => {
    await rejectsSanitized(assertHealthyResponse(Response.json(HEALTHY_BODY, { status: 200 })));
    for (const cacheControl of ["no-cache", "public, max-age=60", "no-store, max-age=0", ""]) {
      await rejectsSanitized(
        assertUnavailableResponse(
          responseLike({
            headers: { "Content-Type": "application/json", "Cache-Control": cacheControl },
          }),
        ),
      );
    }
  });

  test("19. a false full-health 200 fed into the unavailable assertion must throw", async () => {
    await rejectsSanitized(assertUnavailableResponse(routeResponse(HEALTHY_BODY, 200)));
  });

  test("timing: monotonic measurement, <=5,000 ms limit and watchdog beyond five seconds", async () => {
    assert.equal(MAX_RESPONSE_MS, 5_000);
    assert.equal(WATCHDOG_MS, 6_000);
    assert.ok(WATCHDOG_MS > MAX_RESPONSE_MS);

    const { response, elapsedMs } = await measureRequest(async () => {
      await delay(5);
      return routeResponse(UNAVAILABLE_BODY, 503);
    });
    assert.ok(elapsedMs >= 0 && Number.isFinite(elapsedMs));
    const observation = await assertUnavailableResponse(response, { elapsedMs });
    assert.equal(observation.elapsedMs, elapsedMs);

    assertWithinDeadline(0);
    assertWithinDeadline(5_000);
    for (const invalid of [5_000.5, 6_000, -1, Number.NaN, Number.POSITIVE_INFINITY, "10"]) {
      assert.throws(() => assertWithinDeadline(invalid), assert.AssertionError);
    }
    await rejectsSanitized(
      assertHealthyResponse(routeResponse(HEALTHY_BODY, 200), { elapsedMs: 5_001 }),
    );
  });

  test("timing: watchdog expiry, disconnect and missing response are failures", async () => {
    // Shortened watchdog only for this self-test; the shared default stays at six seconds.
    await rejectsSanitized(measureRequest(never, { watchdogMs: 20 }));
    await rejectsSanitized(
      measureRequest(() => Promise.reject(new Error("ECONNRESET test-only-password")), {
        watchdogMs: 1_000,
      }),
      "test-only-password",
    );
    await rejectsSanitized(measureRequest(async () => undefined, { watchdogMs: 1_000 }));
  });
});

// --- Real database loss / recovery lifecycle (T008/T009 main-sequence subset) ------------------
//
// One unique Compose project per run from tests/compose.test.yaml: the production app image and
// PostgreSQL 17 (pinned digest), a project-owned network and volume, generated credentials passed
// only through the child-process environment, the app on a dynamic loopback port and no host DB
// port. Docker/Compose being unavailable is a failure, never a skip. Child-process output is never
// echoed (it may carry environment values); failures report only a fixed label and exit status.

const REPO_ROOT = fileURLToPath(new URL("../..", import.meta.url));
const TEST_COMPOSE_FILE = fileURLToPath(new URL("../compose.test.yaml", import.meta.url));

const BATCH_SIZE = 10;
// Outer node:test bound; every step below has its own tighter bound so cleanup still runs.
const LIFECYCLE_TIMEOUT_MS = 30 * 60_000;
const COMPOSE_CHECK_TIMEOUT_MS = 30_000;
const COMPOSE_UP_TIMEOUT_MS = 12 * 60_000; // image build + bounded --wait
const COMPOSE_WAIT_TIMEOUT_S = 180;
const COMPOSE_STEP_TIMEOUT_MS = 120_000;
const COMPOSE_DOWN_TIMEOUT_MS = 180_000;
const READINESS_LIMIT_MS = 120_000;
const READINESS_POLL_MS = 500;

/** Unique project name and fresh credentials; the values are never printed. */
function createFixture() {
  const suffix = randomBytes(6).toString("hex");
  const env = {};
  for (const [key, value] of Object.entries(process.env)) {
    // Developer Compose selections must not leak into the owned project.
    if (!key.startsWith("COMPOSE_") && !key.startsWith("POSTGRES_")) {
      env[key] = value;
    }
  }
  env.POSTGRES_DB = `poc_${randomBytes(6).toString("hex")}`;
  env.POSTGRES_USER = `u_${randomBytes(6).toString("hex")}`;
  env.POSTGRES_PASSWORD = randomBytes(24).toString("base64url");
  return { project: `toolhunter-d2b-${suffix}`, env };
}

/** Runs `docker <args>`; a failure carries only `label` and the exit status, never output. */
function docker(fixture, args, label, timeoutMs) {
  return new Promise((resolve, reject) => {
    execFile(
      "docker",
      args,
      {
        cwd: REPO_ROOT,
        env: fixture.env,
        timeout: timeoutMs,
        killSignal: "SIGKILL",
        maxBuffer: 64 * 1024 * 1024,
        windowsHide: true,
      },
      (error, stdout) => {
        if (!error) {
          resolve(String(stdout).trim());
          return;
        }
        let reason;
        if (error.code === "ENOENT") {
          reason = "docker executable not found";
        } else if (error.killed) {
          reason = `timed out after ${timeoutMs} ms`;
        } else if (typeof error.code === "number") {
          reason = `exit code ${error.code}`;
        } else {
          reason = "could not be executed";
        }
        reject(new assert.AssertionError({ message: `${label} failed (${reason})` }));
      },
    );
  });
}

function compose(fixture, args, label, timeoutMs = COMPOSE_STEP_TIMEOUT_MS) {
  const projectArgs = ["compose", "-p", fixture.project, "-f", TEST_COMPOSE_FILE];
  return docker(fixture, [...projectArgs, ...args], label, timeoutMs);
}

function parseJson(text, label) {
  try {
    return JSON.parse(text);
  } catch {
    assert.fail(`${label}: unexpected output format`);
  }
}

async function containerId(fixture, service) {
  const id = await compose(fixture, ["ps", "--all", "-q", service], `locate ${service} container`);
  if (!/^[0-9a-f]{12,64}$/.test(id)) {
    assert.fail(`expected exactly one ${service} container in the owned project`);
  }
  return id;
}

/** Only the State object is read; the full inspect output would include the container env. */
async function containerState(fixture, id, label) {
  const state = parseJson(
    await docker(fixture, ["inspect", "--format", "{{json .State}}", id], label, COMPOSE_STEP_TIMEOUT_MS),
    label,
  );
  return { running: state?.Running === true, startedAt: String(state?.StartedAt ?? "") };
}

async function appHttpBaseUrl(fixture) {
  const published = await compose(fixture, ["port", "app", "3000"], "discover app HTTP port");
  const match = /^127\.0\.0\.1:(\d{1,5})$/.exec(published);
  if (match === null) {
    assert.fail("app HTTP port is not published on 127.0.0.1 with a single dynamic port");
  }
  return `http://127.0.0.1:${match[1]}`;
}

/** One real GET; the body is read inside the measured interval. */
async function getHealth(baseUrl) {
  const response = await fetch(`${baseUrl}/api/health`, { signal: AbortSignal.timeout(WATCHDOG_MS) });
  const body = await response.text();
  return { status: response.status, headers: response.headers, body };
}

async function timedHealthRequest(baseUrl) {
  return measureRequest(() => getHealth(baseUrl));
}

/**
 * Bounded readiness: polls until exact full health. Every intermediate answer must be the exact
 * database-unavailable contract; transport failure or any other answer fails immediately.
 */
async function waitForFullHealth(baseUrl, label) {
  const deadline = performance.now() + READINESS_LIMIT_MS;
  for (let attempt = 1; ; attempt += 1) {
    const { response, elapsedMs } = await withContext(`${label} attempt ${attempt}`, () =>
      timedHealthRequest(baseUrl),
    );
    if (response.status === 200) {
      await withContext(`${label} attempt ${attempt}`, () =>
        assertHealthyResponse(response, { elapsedMs }),
      );
      return attempt;
    }
    await withContext(`${label} attempt ${attempt}`, () =>
      assertUnavailableResponse(response, { elapsedMs }),
    );
    if (performance.now() >= deadline) {
      assert.fail(`${label}: full health not reached within ${READINESS_LIMIT_MS} ms`);
    }
    await delay(READINESS_POLL_MS);
  }
}

/** Exactly BATCH_SIZE sequential requests, each checked with the shared exact assertion. */
async function runBatch(baseUrl, phase, assertResponse) {
  let maxElapsedMs = 0;
  for (let index = 0; index < BATCH_SIZE; index += 1) {
    await withContext(`${phase} request ${index}`, async () => {
      const { response, elapsedMs } = await timedHealthRequest(baseUrl);
      await assertResponse(response, { elapsedMs });
      maxElapsedMs = Math.max(maxElapsedMs, elapsedMs);
    });
  }
  return maxElapsedMs;
}

/** Prefixes a sanitized assertion message with where it happened. */
async function withContext(where, run) {
  try {
    return await run();
  } catch (error) {
    // Assertion messages from the shared helper and this file are already sanitized; anything
    // else is replaced by a fixed message so no raw transport/driver detail is printed.
    const detail = error instanceof assert.AssertionError ? error.message : "unexpected failure";
    throw new assert.AssertionError({ message: `${where}: ${detail}` });
  }
}

async function assertSameRunningApp(fixture, identity, when) {
  const id = await containerId(fixture, "app");
  assert.equal(id, identity.id, `${when}: app container was replaced`);
  const state = await containerState(fixture, id, "inspect app container");
  assert.equal(state.running, true, `${when}: app container is not running`);
  assert.equal(state.startedAt, identity.startedAt, `${when}: app container was restarted`);
}

describe("real database loss and recovery (production image + PostgreSQL 17)", () => {
  test(
    "10 healthy -> stop db -> 10 database-loss -> start db -> 10 recovery, same app process",
    { timeout: LIFECYCLE_TIMEOUT_MS },
    async (t) => {
      const fixture = createFixture();
      let owned = false;
      let primaryError;

      try {
        // Missing Docker or Compose is a hard failure, never a skip.
        await docker(
          fixture,
          ["compose", "version"],
          "Docker/Compose availability check (required; this test never skips)",
          COMPOSE_CHECK_TIMEOUT_MS,
        );

        owned = true;
        await compose(
          fixture,
          ["up", "-d", "--build", "--wait", "--wait-timeout", String(COMPOSE_WAIT_TIMEOUT_S)],
          "bounded fixture startup",
          COMPOSE_UP_TIMEOUT_MS,
        );

        const dbId = await containerId(fixture, "db");
        const dbPorts = await docker(
          fixture,
          ["inspect", "--format", "{{json .HostConfig.PortBindings}}", dbId],
          "inspect db port bindings",
          COMPOSE_STEP_TIMEOUT_MS,
        );
        const bindings = parseJson(dbPorts, "inspect db port bindings");
        assert.ok(
          bindings === null || Object.keys(bindings).length === 0,
          "db must not publish any host port",
        );

        const baseUrl = await appHttpBaseUrl(fixture);
        const startupAttempts = await waitForFullHealth(baseUrl, "startup readiness");
        t.diagnostic(`startup readiness reached after ${startupAttempts} request(s)`);

        const appId = await containerId(fixture, "app");
        const appState = await containerState(fixture, appId, "inspect app container");
        assert.equal(appState.running, true, "app container is not running after startup");
        assert.ok(appState.startedAt.length > 0, "app container StartedAt is missing");
        const identity = { id: appId, startedAt: appState.startedAt };

        const healthyMax = await runBatch(baseUrl, "healthy", assertHealthyResponse);
        t.diagnostic(`healthy: ${BATCH_SIZE}/${BATCH_SIZE} exact HTTP 200 (max ${Math.round(healthyMax)} ms)`);

        await compose(fixture, ["stop", "db"], "stop db");
        const dbStopped = await containerState(fixture, dbId, "inspect db container");
        assert.equal(dbStopped.running, false, "db container is still running after stop");
        await assertSameRunningApp(fixture, identity, "after db stop");

        // A full-health answer while db is stopped fails here (exact 503 contract only).
        const lossMax = await runBatch(baseUrl, "database-loss", assertUnavailableResponse);
        t.diagnostic(`database-loss: ${BATCH_SIZE}/${BATCH_SIZE} exact HTTP 503 (max ${Math.round(lossMax)} ms)`);
        await assertSameRunningApp(fixture, identity, "after database-loss batch");
        const dbStillStopped = await containerState(fixture, dbId, "inspect db container");
        assert.equal(dbStillStopped.running, false, "db container restarted during database-loss batch");

        await compose(fixture, ["start", "db"], "start db");
        const recoveryAttempts = await waitForFullHealth(baseUrl, "recovery readiness");
        t.diagnostic(`recovery readiness reached after ${recoveryAttempts} request(s)`);
        await assertSameRunningApp(fixture, identity, "after db start");

        const recoveryMax = await runBatch(baseUrl, "database-recovery", assertHealthyResponse);
        t.diagnostic(
          `database-recovery: ${BATCH_SIZE}/${BATCH_SIZE} exact HTTP 200 (max ${Math.round(recoveryMax)} ms)`,
        );
        await assertSameRunningApp(fixture, identity, "after database-recovery batch");
      } catch (error) {
        primaryError = error;
      }

      // Always runs, on success and on every failure path: removes only this run's containers,
      // network, volume and locally built image.
      if (owned) {
        try {
          await compose(
            fixture,
            ["down", "-v", "--remove-orphans", "--rmi", "local", "--timeout", "5"],
            "owned fixture cleanup",
            COMPOSE_DOWN_TIMEOUT_MS,
          );
        } catch (cleanupError) {
          if (primaryError === undefined) {
            primaryError = cleanupError;
          } else {
            t.diagnostic("owned fixture cleanup also failed");
          }
        }
      }
      if (primaryError !== undefined) {
        throw primaryError;
      }
    },
  );
});
