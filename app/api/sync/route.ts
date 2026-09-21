import { NextResponse } from "next/server";
import { timingSafeEqual } from "node:crypto";
import { fetchAllSources } from "@/lib/sync";

export const dynamic = "force-dynamic";

function authorized(request: Request) {
  const expected = process.env.SYNC_SECRET;
  if (!expected) return false; // no secret configured -> sync stays closed
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "") ?? "";
  const a = Buffer.from(supplied);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

async function run(request: Request) {
  if (!authorized(request)) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  try {
    const result = await fetchAllSources();
    return NextResponse.json({ ok: true, syncedAt: new Date().toISOString(), ...result });
  } catch (error) {
    return NextResponse.json({ ok: false, error: error instanceof Error ? error.message : "Sync failed" }, { status: 500 });
  }
}
export async function POST(request: Request) { return run(request); }
export async function GET(request: Request) { return run(request); }