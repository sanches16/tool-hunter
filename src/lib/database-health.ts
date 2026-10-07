import { performance } from "node:perf_hooks";
import { clearTimeout, setTimeout } from "node:timers";
import { Client, type QueryConfig } from "pg";

/** One total monotonic budget for configuration, connection/authentication and query (FR-005). */
export const PROBE_BUDGET_MS = 4_000;

/** Upper bound for graceful client shutdown after a healthy result; never delays the response. */
const CLOSE_GRACE_MS = 1_000;

const PROBE_SQL = "SELECT 1 AS ok";

export interface ProbeDeadline {
  /** Milliseconds left in the total budget; zero or less means the deadline has passed. */
  remaining(): number;
}

/** Starts the total probe budget. Call at handler entry, before validation or connecting. */
export function startProbeDeadline(): ProbeDeadline {
  const expiresAt = performance.now() + PROBE_BUDGET_MS;
  return { remaining: () => expiresAt - performance.now() };
}

export interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  user: string;
  password: string;
}

/**
 * Validates one snapshot of the required connection variables. Returns null for any missing or
 * invalid value; never falls back to defaults, never alters supplied values, never reports which
 * value failed or what it contained.
 */
export function readDatabaseConfig(env: NodeJS.ProcessEnv): DatabaseConfig | null {
  const snapshot = {
    host: env.POSTGRES_HOST,
    port: env.POSTGRES_PORT,
    database: env.POSTGRES_DB,
    user: env.POSTGRES_USER,
    password: env.POSTGRES_PASSWORD,
  };

  if (
    !isNonEmpty(snapshot.host) ||
    !isNonEmpty(snapshot.database) ||
    !isNonEmpty(snapshot.user) ||
    !isNonEmpty(snapshot.password) ||
    snapshot.port === undefined ||
    !/^[0-9]+$/.test(snapshot.port)
  ) {
    return null;
  }

  const port = Number(snapshot.port);
  if (!Number.isSafeInteger(port) || port < 1 || port > 65_535) {
    return null;
  }

  return {
    host: snapshot.host,
    port,
    database: snapshot.database,
    user: snapshot.user,
    password: snapshot.password,
  };
}

function isNonEmpty(value: string | undefined): value is string {
  return typeof value === "string" && value.length > 0;
}

/**
 * Code-level test-client injection boundary (T011). The application always uses the default
 * pg-backed factory; there is no environment or runtime switch that selects another client.
 */
export interface ProbeClient {
  connect(): Promise<unknown>;
  /** Runs the probe SQL and resolves with its result rows. */
  query(sql: string, timeoutMs: number): Promise<unknown[]>;
  /** Graceful close; may never settle if the transport is stalled. */
  close(): Promise<unknown>;
  /** Forcibly destroys the underlying transport. Must be safe to call repeatedly. */
  destroy(): void;
}

export type ProbeClientFactory = (config: DatabaseConfig, budgetMs: number) => ProbeClient;

export const createPgProbeClient: ProbeClientFactory = (config, budgetMs) => {
  const guardMs = Math.max(1, Math.ceil(budgetMs));
  const client = new Client({
    host: config.host,
    port: config.port,
    database: config.database,
    user: config.user,
    password: config.password,
    // Driver/server guards, bounded by the remaining total budget; not additional budgets.
    connectionTimeoutMillis: guardMs,
    statement_timeout: guardMs,
  });
  // Observe asynchronous driver errors (including late ones after destroy) so they never surface
  // as unhandled 'error' events. Their content is intentionally discarded.
  client.on("error", () => {});

  return {
    connect: () => client.connect(),
    query: async (sql, timeoutMs) => {
      const queryConfig: QueryConfig & { query_timeout: number } = {
        text: sql,
        query_timeout: Math.max(1, Math.ceil(timeoutMs)),
      };
      const result = await client.query(queryConfig);
      return result.rows;
    },
    close: () => client.end(),
    destroy: () => {
      client.connection.stream.destroy();
    },
  };
};

/**
 * Performs one fresh database observation: validate configuration, open a new short-lived client,
 * run `SELECT 1` and verify its result, all within the deadline started by the caller.
 * Resolves true only for this observation's successful SQL; resolves false for every
 * configuration, connection, query, result or deadline failure. Never rejects and retains no state.
 */
export async function probeDatabase(
  deadline: ProbeDeadline,
  createClient: ProbeClientFactory = createPgProbeClient,
): Promise<boolean> {
  try {
    const config = readDatabaseConfig(process.env);
    if (config === null) {
      return false;
    }
    const budgetMs = deadline.remaining();
    if (budgetMs <= 0) {
      return false;
    }
    return await observe(config, budgetMs, deadline, createClient);
  } catch {
    return false;
  }
}

function observe(
  config: DatabaseConfig,
  budgetMs: number,
  deadline: ProbeDeadline,
  createClient: ProbeClientFactory,
): Promise<boolean> {
  return new Promise<boolean>((resolve) => {
    const client = createClient(config, budgetMs);
    let settled = false;

    const finish = (healthy: boolean): void => {
      // The first outcome wins; late success or late errors cannot change it.
      if (settled) {
        return;
      }
      settled = true;
      clearTimeout(deadlineTimer);
      resolve(healthy);
      release(client, healthy);
    };

    // Authoritative total deadline, independent of any driver behavior.
    const deadlineTimer = setTimeout(() => finish(false), budgetMs);

    void (async () => {
      try {
        await client.connect();
        if (settled) {
          return;
        }
        const remainingMs = deadline.remaining();
        if (remainingMs <= 0) {
          finish(false);
          return;
        }
        const rows = await client.query(PROBE_SQL, remainingMs);
        finish(isExpectedResult(rows));
      } catch {
        finish(false);
      }
    })();
  });
}

function isExpectedResult(rows: unknown): boolean {
  if (!Array.isArray(rows) || rows.length !== 1) {
    return false;
  }
  const row: unknown = rows[0];
  return (
    typeof row === "object" &&
    row !== null &&
    Object.keys(row).length === 1 &&
    (row as { ok?: unknown }).ok === 1
  );
}

/** Reclaims the client without delaying the already selected response. */
function release(client: ProbeClient, healthy: boolean): void {
  if (!healthy) {
    // Failed or timed-out observation: no live transport may remain.
    safeDestroy(client);
    return;
  }

  // Healthy observation: close gracefully, but force-destroy if that does not finish promptly.
  const graceTimer = setTimeout(() => safeDestroy(client), CLOSE_GRACE_MS);
  graceTimer.unref();
  let closing: Promise<unknown>;
  try {
    closing = client.close();
  } catch {
    clearTimeout(graceTimer);
    safeDestroy(client);
    return;
  }
  closing.then(
    () => clearTimeout(graceTimer),
    () => {
      clearTimeout(graceTimer);
      safeDestroy(client);
    },
  );
}

function safeDestroy(client: ProbeClient): void {
  try {
    client.destroy();
  } catch {
    // Destroy failures carry no information the response may use.
  }
}
