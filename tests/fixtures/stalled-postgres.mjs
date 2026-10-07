import { createServer as createHttpServer } from "node:http";
import { createServer as createTcpServer } from "node:net";

// Test-only silent PostgreSQL dependency (T007, Iteration D2C1). Used only by the silent-listener
// suite in tests/integration/health.test.mjs through tests/compose.test.yaml; never part of the app.
//
// - LISTEN_PORT accepts TCP connections on the project-owned Compose network and never writes a
//   single byte, so the PostgreSQL startup/authentication exchange never completes. Incoming bytes
//   are discarded unread; there is deliberately no idle timeout, so only the client side (the app's
//   probe) can release a connection.
// - Only this fixture's currently ACTIVE accepted sockets are tracked; a socket leaves the set on
//   close or error.
// - CONTROL_PORT serves exactly one read-only endpoint, GET /active -> {"active": <n>}.
// - Payloads, credentials, peer details and socket data are never logged.
// - SIGTERM/SIGINT: bounded shutdown that destroys every owned socket.

const LISTEN_PORT = 5432;
const CONTROL_PORT = 8080;
const SHUTDOWN_LIMIT_MS = 2_000;

/** Currently active accepted sockets owned by this fixture. */
const active = new Set();

const listener = createTcpServer((socket) => {
  active.add(socket);
  const forget = () => {
    active.delete(socket);
  };
  socket.once("close", forget);
  // Error content is discarded; 'close' follows, the set is updated eagerly anyway.
  socket.on("error", forget);
  // Flowing mode with no 'data' listener: client bytes are dropped without being read or stored.
  socket.resume();
});

const control = createHttpServer((request, response) => {
  if (request.method === "GET" && request.url === "/active") {
    const body = JSON.stringify({ active: active.size });
    response.writeHead(200, {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Content-Length": String(body.length),
    });
    response.end(body);
    return;
  }
  response.writeHead(404, { "Content-Length": "0" });
  response.end();
});

/** Listener failure: fixed message only, then exit so the fixture never silently stops accepting. */
function failServer() {
  console.error("stalled-postgres fixture: server error");
  process.exit(1);
}

listener.on("error", failServer);
control.on("error", failServer);
listener.listen(LISTEN_PORT, "0.0.0.0");
control.listen(CONTROL_PORT, "0.0.0.0");

let shuttingDown = false;

function shutdown() {
  if (shuttingDown) {
    return;
  }
  shuttingDown = true;
  // Bounded: exit even if a close callback never arrives.
  setTimeout(() => process.exit(1), SHUTDOWN_LIMIT_MS).unref();

  for (const socket of active) {
    socket.destroy();
  }
  active.clear();
  control.closeAllConnections();

  let pending = 2;
  const closed = () => {
    pending -= 1;
    if (pending === 0) {
      process.exit(0);
    }
  };
  listener.close(closed);
  control.close(closed);
}

process.once("SIGTERM", shutdown);
process.once("SIGINT", shutdown);
