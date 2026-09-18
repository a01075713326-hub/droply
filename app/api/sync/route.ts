import { NextResponse } from "next/server";
import { fetchAllSources } from "@/lib/sync";

export const dynamic = "force-dynamic";

async function run(request: Request) {
  const expected = process.env.SYNC_SECRET;
  if (expected) {
    const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
    if (supplied !== expected) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  try {
    const result = await fetchAllSources();
    return NextResponse.json({ ok: true, syncedAt: new Date().toISOString(), ...result });
  } catch (error) {
    return NextResponse.json({ ok: false, error: error instanceof Error ? error.message : "Sync failed" }, { status: 500 });
  }
}
export async function POST(request: Request) { return run(request); }
export async function GET(request: Request) { return run(request); }
