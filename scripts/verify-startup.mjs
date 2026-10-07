import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { randomBytes } from "node:crypto";
import { performance } from "node:perf_hooks";
import { setTimeout as delay } from "node:timers/promises";
import { fileURLToPath } from "node:url";

import {
  assertHealthyResponse,
  assertUnavailableResponse,
  measureRequest,
  WATCHDOG_MS,
} from "../tests/helpers/health-assertions.mjs";

/**
 * `npm run verify:startup` (T019): one fresh, independent startup proof of the production image
 * with PostgreSQL 17 from tests/compose.test.yaml (default services `app` + `db` only).
 *
 * - Docker and Compose are required; a missing prerequisite is a FAIL, never a skip.
 * - A unique Compose project per run with generated DB/user/password values passed only through
 *   the child-process environment (inherited COMPOSE_* / POSTGRES_* are stripped).
 * - Phases: prerequisites -> build -> start (bounded --wait) -> isolation (db publishes no host
 *   port, app HTTP on 127.0.0.1 with a dynamic port only) -> bounded readiness -> one exact
 *   healthy request (HTTP 200 ok/ok/ok, Cache-Control: no-store, <=5,000 ms) -> cleanup.
 * - Cleanup (`down -v --remove-orphans --rmi local`) always runs once ownership is taken, also on
 *   failure and on SIGINT/SIGTERM, and is followed by a residue check of the owned project.
 * - Output is sanitized: docker output, logs, env, compose config, credentials, project name,
 *   ports and driver errors are never printed; failures report the phase, a fixed reason and the
 *   validated per-service container state only.
 */

const REPO_ROOT = fileURLToPath(new URL("..", import.meta.url));
const COMPOSE_FILE = fileURLToPath(new URL("../tests/compose.test.yaml", import.meta.url));
const SERVICES = Object.freeze(["app", "db"]);

const PREREQUISITE_TIMEOUT_MS = 30_000;
const BUILD_TIMEOUT_MS = 12 * 60_000;
const WAIT_TIMEOUT_S = 180;
/** Start phase only (image already built): bounded --wait plus margin for container creation. */
const START_TIMEOUT_MS = WAIT_TIMEOUT_S * 1_000 + 120_000;
const STEP_TIMEOUT_MS = 120_000;
const DIAGNOSTIC_TIMEOUT_MS = 15_000;
const DOWN_TIMEOUT_MS = 180_000;
const READINESS_LIMIT_MS = 120_000;
const READINESS_POLL_MS = 500;
/** Only small, format-checked outputs are parsed; anything beyond this is discarded unread. */
const MAX_CAPTURE_BYTES = 1024 * 1024;

/**
 * Strict inspect template: only these State fields are emitted, never .Config.Env, logs or the
 * healthcheck Log/Output text.
 */
const SAFE_STATE_FORMAT =
  '{"Running":{{json .State.Running}},"ExitCode":{{json .State.ExitCode}},' +
  '"Health":{{if .State.Health}}{{json .State.Health.Status}}{{else}}null{{end}},' +
  '"StartedAt":{{json .State.StartedAt}},"FinishedAt":{{json .State.FinishedAt}}}';
const HEALTH_STATUSES = new Set(["starting", "healthy", "unhealthy", "none"]);
const DOCKER_TIMESTAMP = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,9})?Z$/;
const CONTAINER_ID = /^[0-9a-f]{12,64}$/;

const PHASE_LABELS = Object.freeze({
  prerequisites: "prerequisites (Docker + Compose, required; never skipped)",
  build: "build (app image)",
  start: "start (app + db, bounded wait)",
  isolation: "isolation (db host ports, app loopback binding)",
  readiness: "readiness (bounded polling for full health)",
  health: "health (exact HTTP 200 check)",
});

/** Failure with a fixed, already-sanitized message. */
class VerifyError extends Error {}

function fail(message) {
  throw new VerifyError(message);
}

/** Only messages built by this script or the shared assertion helper are ever printed. */
function safeMessage(error) {
  if (error instanceof VerifyError || error instanceof assert.AssertionError) {
    return error.message;
  }
  return "unexpected failure";
}

// --- Private ephemeral configuration -------------------------------------------------------------

function createRun() {
  const env = {};
  for (const [key, value] of Object.entries(process.env)) {
    // Developer Compose selections and database values must not leak into the owned project.
    if (!key.startsWith("COMPOSE_") && !key.startsWith("POSTGRES_")) {
      env[key] = value;
    }
  }
  env.POSTGRES_DB = `poc_${randomBytes(6).toString("hex")}`;
  env.POSTGRES_USER = `u_${randomBytes(6).toString("hex")}`;
  env.POSTGRES_PASSWORD = randomBytes(24).toString("base64url");
  return { project: `toolhunter-verify-${randomBytes(6).toString("hex")}`, env };
}

const run = createRun();
const state = {
  phase: "prerequisites",
  owned: false,
  timings: {},
  active: new Set(),
  signals: 0,
  finalizing: undefined,
};

// --- Child processes (output captured in memory, never printed) ----------------------------------

/**
 * Runs `docker <args>` in its own process group (a terminal Ctrl-C reaches only this script, which
 * then controls cleanup). Resolves with trimmed stdout; stderr is discarded. A failure carries only
 * `label` and a fixed reason.
 */
function docker(args, label, timeoutMs) {
  return new Promise((resolve, reject) => {
    let child;
    try {
      child = spawn("docker", args, {
        cwd: REPO_ROOT,
        env: run.env,
        stdio: ["ignore", "pipe", "ignore"],
        detached: true,
        windowsHide: true,
      });
    } catch {
      reject(new VerifyError(`${label} failed (could not be executed)`));
      return;
    }

    state.active.add(child);
    const chunks = [];
    let captured = 0;
    let timedOut = false;
    let settled = false;
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeoutMs);

    const settle = (reason, stdout) => {
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(timer);
      state.active.delete(child);
      if (reason === undefined) {
        resolve(stdout);
      } else {
        reject(new VerifyError(`${label} failed (${reason})`));
      }
    };

    child.stdout.on("data", (chunk) => {
      if (captured < MAX_CAPTURE_BYTES) {
        chunks.push(chunk);
        captured += chunk.length;
      }
    });
    child.on("error", (error) => {
      settle(error?.code === "ENOENT" ? "docker executable not found" : "could not be executed");
    });
    child.on("close", (code) => {
      if (timedOut) {
        settle(`timed out after ${timeoutMs} ms`);
      } else if (code === 0) {
        settle(undefined, Buffer.concat(chunks).toString("utf8").trim());
      } else if (typeof code === "number") {
        settle(`exit code ${code}`);
      } else {
        settle("terminated by a signal");
      }
    });
  });
}

function compose(args, label, timeoutMs = STEP_TIMEOUT_MS) {
  return docker(["compose", "-p", run.project, "-f", COMPOSE_FILE, ...args], label, timeoutMs);
}

function parseJson(text, label) {
  try {
    return JSON.parse(text);
  } catch {
    return fail(`${label}: unexpected output format`);
  }
}

function lines(text) {
  return text.split(/\s+/).filter((entry) => entry !== "");
}

async function containerId(service) {
  const ids = lines(await compose(["ps", "--all", "-q", service], `locate ${service} container`));
  if (ids.length !== 1 || !CONTAINER_ID.test(ids[0])) {
    fail(`expected exactly one ${service} container in the owned project (found ${ids.length})`);
  }
  return ids[0];
}

async function portBindings(id, service) {
  const label = `inspect ${service} port bindings`;
  const bindings = parseJson(
    await docker(["inspect", "--format", "{{json .HostConfig.PortBindings}}", id], label, STEP_TIMEOUT_MS),
    label,
  );
  if (bindings !== null && (typeof bindings !== "object" || Array.isArray(bindings))) {
    fail(`${label}: unexpected output format`);
  }
  return bindings ?? {};
}

/** Containers, networks, volumes and images labelled with (or named after) the owned project. */
async function projectResources(label) {
  const projectLabel = `label=com.docker.compose.project=${run.project}`;
  const queries = [
    ["containers", ["ps", "--all", "-q", "--filter", projectLabel]],
    ["networks", ["network", "ls", "-q", "--filter", projectLabel]],
    ["volumes", ["volume", "ls", "-q", "--filter", projectLabel]],
    ["images", ["image", "ls", "-q", "--filter", projectLabel]],
    ["images", ["image", "ls", "-q", "--filter", `reference=${run.project}-*`]],
  ];
  const found = {};
  for (const [kind, args] of queries) {
    const count = lines(await docker(args, `${label} (${kind})`, STEP_TIMEOUT_MS)).length;
    found[kind] = (found[kind] ?? 0) + count;
  }
  return Object.entries(found)
    .filter(([, count]) => count > 0)
    .map(([kind, count]) => `${kind}=${count}`);
}

// --- Phases ----------------------------------------------------------------------------------------

async function phase(name, body) {
  state.phase = name;
  const startedAt = performance.now();
  const result = await body();
  state.timings[name] = performance.now() - startedAt;
  return result;
}

async function checkPrerequisites() {
  await docker(["compose", "version"], "Docker Compose availability check", PREREQUISITE_TIMEOUT_MS);
  await docker(
    ["version", "--format", "{{.Server.Version}}"],
    "Docker daemon availability check",
    PREREQUISITE_TIMEOUT_MS,
  );
  const existing = await projectResources("owned project name check");
  if (existing.length > 0) {
    // Not ours: never adopt or clean resources this run did not create.
    fail("generated project name is already in use; nothing was created or removed");
  }
}

async function checkIsolation() {
  const dbBindings = await portBindings(await containerId("db"), "db");
  if (Object.keys(dbBindings).length !== 0) {
    fail("db must not publish any host port");
  }

  const appBindings = await portBindings(await containerId("app"), "app");
  const keys = Object.keys(appBindings);
  const entries = appBindings["3000/tcp"];
  if (keys.length !== 1 || keys[0] !== "3000/tcp" || !Array.isArray(entries) || entries.length === 0) {
    fail("app must publish only its HTTP port 3000/tcp");
  }
  for (const binding of entries) {
    if (binding?.HostIp !== "127.0.0.1") {
      fail("app HTTP port must be bound to 127.0.0.1 only");
    }
    if (!["", "0", undefined].includes(binding?.HostPort)) {
      fail("app HTTP host port must be dynamic");
    }
  }

  const published = await compose(["port", "app", "3000"], "discover app HTTP port");
  const match = /^127\.0\.0\.1:(\d{1,5})$/.exec(published);
  const port = match === null ? 0 : Number(match[1]);
  if (port < 1 || port > 65_535) {
    fail("app HTTP port is not published on 127.0.0.1 with a single dynamic port");
  }
  return `http://127.0.0.1:${port}`;
}

/** One real GET; the body is read inside the measured interval. */
async function getHealth(baseUrl) {
  const response = await fetch(`${baseUrl}/api/health`, { signal: AbortSignal.timeout(WATCHDOG_MS) });
  const body = await response.text();
  return { status: response.status, headers: response.headers, body };
}

/** Prefixes a sanitized message with where it happened. */
async function withContext(where, body) {
  try {
    return await body();
  } catch (error) {
    throw new VerifyError(`${where}: ${safeMessage(error)}`);
  }
}

/**
 * Bounded readiness: polls until exact full health. Every intermediate answer must be the exact
 * database-unavailable contract; a transport failure or any other answer fails immediately.
 */
async function waitForFullHealth(baseUrl) {
  const deadline = performance.now() + READINESS_LIMIT_MS;
  for (let attempt = 1; ; attempt += 1) {
    const healthy = await withContext(`readiness attempt ${attempt}`, async () => {
      const { response, elapsedMs } = await measureRequest(() => getHealth(baseUrl));
      if (response.status === 200) {
        await assertHealthyResponse(response, { elapsedMs });
        return true;
      }
      await assertUnavailableResponse(response, { elapsedMs });
      return false;
    });
    if (healthy) {
      return attempt;
    }
    if (performance.now() >= deadline) {
      fail(`full health not reached within ${READINESS_LIMIT_MS} ms`);
    }
    await delay(READINESS_POLL_MS);
  }
}

// --- Failure diagnostics and cleanup (never throw) -------------------------------------------------

/** Re-validates every inspected field so only known-safe values are ever printed. */
function formatSafeState(text) {
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    return "state unreadable";
  }
  const running = typeof parsed?.Running === "boolean" ? String(parsed.Running) : "?";
  const exitCode = Number.isSafeInteger(parsed?.ExitCode) ? String(parsed.ExitCode) : "?";
  const health =
    parsed?.Health === null ? "no-healthcheck" : HEALTH_STATUSES.has(parsed?.Health) ? parsed.Health : "?";
  const time = (value) => (typeof value === "string" && DOCKER_TIMESTAMP.test(value) ? value : "?");
  return (
    `Running=${running} ExitCode=${exitCode} Health=${health} ` +
    `StartedAt=${time(parsed?.StartedAt)} FinishedAt=${time(parsed?.FinishedAt)}`
  );
}

/** Failure-only and bounded: one sanitized line per service, collected before cleanup. */
async function serviceDiagnostics() {
  const report = [];
  for (const service of SERVICES) {
    try {
      const ids = lines(
        await compose(["ps", "--all", "-q", service], `diagnose ${service} container`, DIAGNOSTIC_TIMEOUT_MS),
      );
      if (ids.length === 0) {
        report.push(`${service}: container missing`);
        continue;
      }
      if (ids.length !== 1 || !CONTAINER_ID.test(ids[0])) {
        report.push(`${service}: unexpected container listing (${ids.length} entries)`);
        continue;
      }
      const inspected = await docker(
        ["inspect", "--format", SAFE_STATE_FORMAT, ids[0]],
        `diagnose ${service} state`,
        DIAGNOSTIC_TIMEOUT_MS,
      );
      report.push(`${service}: container present ${formatSafeState(inspected)}`);
    } catch (error) {
      report.push(`${service}: state unavailable (${safeMessage(error)})`);
    }
  }
  return report;
}

/** Removes only this run's containers, network, volume and locally built image, then re-checks. */
async function cleanupOwned() {
  if (!state.owned) {
    return { ok: true, note: "not needed (nothing was created)" };
  }
  const startedAt = performance.now();
  try {
    await compose(
      ["down", "-v", "--remove-orphans", "--rmi", "local", "--timeout", "5"],
      "owned project cleanup",
      DOWN_TIMEOUT_MS,
    );
    const residue = await projectResources("owned project residue check");
    if (residue.length > 0) {
      fail(`owned project resources remain after cleanup (${residue.join(", ")})`);
    }
  } catch (error) {
    return { ok: false, note: `FAILED: ${safeMessage(error)}` };
  }
  const ms = performance.now() - startedAt;
  return { ok: true, ms, note: `owned containers, network, volume and local image removed in ${seconds(ms)}` };
}

// --- Reporting -------------------------------------------------------------------------------------

function seconds(ms) {
  return `${(ms / 1_000).toFixed(1)} s`;
}

function write(stream, text) {
  return new Promise((resolve) => stream.write(text, () => resolve()));
}

/** Single exit path for success, failure and interruption; the first caller wins. */
function finalize(outcome) {
  state.finalizing ??= conclude(outcome);
  return state.finalizing;
}

async function conclude(outcome) {
  const diagnostics =
    !outcome.ok && !outcome.interrupted && state.owned ? await serviceDiagnostics() : undefined;
  const cleanup = await cleanupOwned();
  const total = seconds(performance.now() - outcome.startedAt);

  if (outcome.ok && cleanup.ok) {
    const { timings, facts } = outcome;
    const report = [
      "verify:startup PASS",
      "  prerequisites: Docker and Docker Compose available",
      `  build: production app image built in ${seconds(timings.build)}`,
      `  start: app + db healthy within the bounded wait in ${seconds(timings.start)}`,
      "  isolation: db publishes no host port; app HTTP bound to 127.0.0.1 on a dynamic port only",
      `  readiness: full health after ${facts.attempts} request(s) in ${seconds(timings.readiness)}`,
      `  health: ${facts.summary}, Cache-Control: ${facts.cacheControl}`,
      `  cleanup: ${cleanup.note}`,
      `  total: ${total}`,
    ];
    await write(process.stdout, `${report.join("\n")}\n`);
    process.exit(0);
  }

  const failedPhase = outcome.ok ? "cleanup" : (PHASE_LABELS[outcome.phase] ?? outcome.phase);
  const reason = outcome.ok ? "owned project cleanup did not complete" : outcome.reason;
  const report = ["verify:startup FAIL", `  phase: ${failedPhase}`, `  reason: ${reason}`];
  if (diagnostics !== undefined) {
    report.push("  sanitized service state:", ...diagnostics.map((line) => `    ${line}`));
  }
  report.push(`  cleanup: ${cleanup.note}`, `  total: ${total}`);
  await write(process.stderr, `${report.join("\n")}\n`);
  process.exit(outcome.exitCode ?? 1);
}

function installSignalHandlers(startedAt) {
  const onSignal = (signal) => {
    state.signals += 1;
    if (state.signals > 1) {
      // Second interrupt: stop waiting; owned resources may remain.
      for (const child of state.active) {
        child.kill("SIGKILL");
      }
      process.stderr.write("verify:startup FAIL\n  reason: interrupted again; owned cleanup was not awaited\n");
      process.exit(1);
    }
    if (state.finalizing !== undefined) {
      return; // Already reporting/cleaning up; let it finish.
    }
    // Stop in-flight phase commands, then run the normal owned cleanup.
    for (const child of state.active) {
      child.kill("SIGKILL");
    }
    void finalize({
      ok: false,
      interrupted: true,
      phase: state.phase,
      reason: `interrupted by ${signal}`,
      exitCode: signal === "SIGINT" ? 130 : 143,
      startedAt,
    });
  };
  process.on("SIGINT", onSignal);
  process.on("SIGTERM", onSignal);
}

// --- Main ------------------------------------------------------------------------------------------

async function main() {
  const startedAt = performance.now();
  installSignalHandlers(startedAt);

  try {
    await phase("prerequisites", checkPrerequisites);

    // From here on the project may hold resources; cleanup always runs.
    state.owned = true;
    await phase("build", () => compose(["build", "app"], "app image build", BUILD_TIMEOUT_MS));
    await phase("start", () =>
      compose(
        ["up", "-d", "--no-build", "--wait", "--wait-timeout", String(WAIT_TIMEOUT_S), ...SERVICES],
        "start with bounded wait",
        START_TIMEOUT_MS,
      ),
    );
    const baseUrl = await phase("isolation", checkIsolation);
    const attempts = await phase("readiness", () => waitForFullHealth(baseUrl));
    const observation = await phase("health", () =>
      withContext("health check", async () => {
        const { response, elapsedMs } = await measureRequest(() => getHealth(baseUrl));
        return assertHealthyResponse(response, { elapsedMs });
      }),
    );

    await finalize({
      ok: true,
      startedAt,
      timings: state.timings,
      facts: { attempts, summary: observation.summary, cacheControl: observation.cacheControl },
    });
  } catch (error) {
    await finalize({ ok: false, phase: state.phase, reason: safeMessage(error), startedAt });
  }
}

await main();
