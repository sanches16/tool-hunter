import assert from "node:assert/strict";
import { performance } from "node:perf_hooks";
import { clearTimeout, setTimeout } from "node:timers";

/**
 * Shared HTTP assertion helpers for GET /api/health (T006).
 *
 * Every assertion failure is raised with a fixed, sanitized message: response bodies, header
 * values other than the checked ones, and driver/connection details are never echoed, so a
 * misbehaving server cannot leak private connection data through test output.
 */

export const HEALTHY_BODY = Object.freeze({ status: "ok", application: "ok", database: "ok" });
export const UNAVAILABLE_BODY = Object.freeze({
  status: "degraded",
  application: "ok",
  database: "unavailable",
});

/** Maximum accepted request duration (SC-004). */
export const MAX_RESPONSE_MS = 5_000;

/** Watchdog that exceeds five seconds; reaching it is a failure, never a pass. */
export const WATCHDOG_MS = 6_000;

const EXPECTED_KEYS = Object.freeze(["application", "database", "status"]);

/**
 * Runs one request under the watchdog and measures it with the monotonic clock.
 * A watchdog expiry, a rejected request (timeout/disconnect) or a missing response is a failure.
 * `watchdogMs` may only be shortened by the helper's own self-tests.
 */
export async function measureRequest(run, { watchdogMs = WATCHDOG_MS } = {}) {
  let watchdogTimer;
  const watchdog = new Promise((_, reject) => {
    watchdogTimer = setTimeout(() => reject(new WatchdogExpired()), watchdogMs);
  });

  const startedAt = performance.now();
  let response;
  try {
    response = await Promise.race([Promise.resolve().then(run), watchdog]);
  } catch (error) {
    if (error instanceof WatchdogExpired) {
      assert.fail(`health request exceeded the ${watchdogMs} ms watchdog`);
    }
    assert.fail("health request failed before a response (timeout, disconnect or transport error)");
  } finally {
    clearTimeout(watchdogTimer);
  }
  const elapsedMs = performance.now() - startedAt;

  if (response === undefined || response === null) {
    assert.fail("health request produced no response");
  }
  return { response, elapsedMs };
}

/** Asserts a measured duration is a valid monotonic interval within the 5,000 ms limit. */
export function assertWithinDeadline(elapsedMs) {
  if (typeof elapsedMs !== "number" || !Number.isFinite(elapsedMs) || elapsedMs < 0) {
    assert.fail("health request duration is not a valid monotonic measurement");
  }
  if (elapsedMs > MAX_RESPONSE_MS) {
    assert.fail(`health request took longer than ${MAX_RESPONSE_MS} ms`);
  }
}

/** Asserts exact HTTP 200 full health; resolves with the parsed observation. */
export function assertHealthyResponse(response, options) {
  return assertHealthResponse(response, 200, HEALTHY_BODY, options);
}

/** Asserts exact HTTP 503 database-unavailable; resolves with the parsed observation. */
export function assertUnavailableResponse(response, options) {
  return assertHealthResponse(response, 503, UNAVAILABLE_BODY, options);
}

async function assertHealthResponse(response, expectedStatus, expectedBody, { elapsedMs } = {}) {
  if (response === undefined || response === null) {
    assert.fail("health response is missing");
  }
  if (elapsedMs !== undefined) {
    assertWithinDeadline(elapsedMs);
  }

  const httpStatus = response.status;
  if (httpStatus !== expectedStatus) {
    const shown = Number.isInteger(httpStatus) ? httpStatus : "non-numeric";
    assert.fail(`expected HTTP ${expectedStatus}, received HTTP ${shown}`);
  }

  const contentType = readHeader(response.headers, "content-type");
  if (contentType === null || !/^application\/json\s*(;.*)?$/i.test(contentType.trim())) {
    assert.fail("health response Content-Type is not application/json");
  }

  const cacheControl = readHeader(response.headers, "cache-control");
  if (cacheControl === null || cacheControl.trim().toLowerCase() !== "no-store") {
    assert.fail("health response Cache-Control is not exactly no-store");
  }

  const bodyText = await readBody(response);
  let body;
  try {
    body = JSON.parse(bodyText);
  } catch {
    assert.fail("health response body is not valid JSON");
  }

  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    assert.fail("health response body is not a JSON object");
  }
  const keys = Object.keys(body).sort();
  if (keys.length !== EXPECTED_KEYS.length || keys.some((key, i) => key !== EXPECTED_KEYS[i])) {
    assert.fail(
      `health response body must have exactly the fields status, application, database (received ${keys.length} fields)`,
    );
  }
  for (const key of EXPECTED_KEYS) {
    if (body[key] !== expectedBody[key]) {
      assert.fail(`health response field "${key}" does not match HTTP ${expectedStatus} contract`);
    }
  }

  const observation = {
    httpStatus,
    contentType: contentType.trim(),
    cacheControl: cacheControl.trim(),
    body: { status: body.status, application: body.application, database: body.database },
    elapsedMs,
  };
  return Object.freeze({ ...observation, summary: summarize(observation) });
}

/** Sanitized one-line summary: only contract values that already passed the exact check. */
function summarize({ httpStatus, body, elapsedMs }) {
  const timing = elapsedMs === undefined ? "" : ` in ${Math.round(elapsedMs)} ms`;
  return `HTTP ${httpStatus} status=${body.status} application=${body.application} database=${body.database}${timing}`;
}

function readHeader(headers, name) {
  if (headers === undefined || headers === null) {
    return null;
  }
  if (typeof headers.get === "function") {
    const value = headers.get(name);
    return typeof value === "string" ? value : null;
  }
  for (const [key, value] of Object.entries(headers)) {
    if (key.toLowerCase() === name) {
      return typeof value === "string" ? value : null;
    }
  }
  return null;
}

async function readBody(response) {
  let text;
  if (typeof response.text === "function") {
    try {
      text = await response.text();
    } catch {
      assert.fail("health response body could not be read (disconnect or truncated body)");
    }
  } else {
    text = response.body;
  }
  if (typeof text !== "string" || text.length === 0) {
    assert.fail("health response body is missing");
  }
  return text;
}

class WatchdogExpired extends Error {}
