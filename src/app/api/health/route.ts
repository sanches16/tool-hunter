import { probeDatabase, startProbeDeadline } from "@/lib/database-health";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const HEALTHY = { status: "ok", application: "ok", database: "ok" } as const;
const UNAVAILABLE = { status: "degraded", application: "ok", database: "unavailable" } as const;

export async function GET(): Promise<Response> {
  // The total probe deadline starts at handler entry, before configuration is read.
  const deadline = startProbeDeadline();

  let healthy = false;
  try {
    healthy = await probeDatabase(deadline);
  } catch {
    healthy = false;
  }

  return Response.json(healthy ? HEALTHY : UNAVAILABLE, {
    status: healthy ? 200 : 503,
    headers: { "Cache-Control": "no-store" },
  });
}
