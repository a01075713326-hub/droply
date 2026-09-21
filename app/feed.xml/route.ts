import { readFile } from "node:fs/promises";
import path from "node:path";
import { getProjects } from "@/lib/projects";
import { groupEvents, projectEvents, sortRows, storedProjectKeys } from "../feed/feed-utils";
import type { ProjectInfo, RawEvent } from "../feed/feed-utils";
import { buildRss } from "../feed/rss";

export const dynamic = "force-dynamic";

// Same two loaders as app/feed/page.tsx. Kept here on purpose so the page file stays untouched.
async function loadEvents(): Promise<RawEvent[]> {
  try {
    const raw = await readFile(path.join(process.cwd(), "data", "events.json"), "utf8");
    const parsed = JSON.parse(raw.replace(/^\uFEFF/, ""));
    if (Array.isArray(parsed)) return parsed;
    if (parsed && Array.isArray(parsed.events)) return parsed.events;
    return [];
  } catch {
    return [];
  }
}

async function loadProjectInfos(): Promise<ProjectInfo[]> {
  try {
    const projects = await getProjects();
    return projects.map((p) => ({
      slug: String(p.slug ?? ""),
      name: String(p.name ?? ""),
      event: p.event,
      status: p.status,
      chain: p.chain,
      date: p.date,
      firstSeenAt: (p as unknown as { firstSeenAt?: string }).firstSeenAt,
      distributeDate: p.distributeDate,
      tasks: p.tasks?.map((t) => ({ title: t.title, endDate: t.endDate })),
    }));
  } catch {
    return [];
  }
}

export async function GET(): Promise<Response> {
  const [events, projectInfos] = await Promise.all([loadEvents(), loadProjectInfos()]);
  const rows = sortRows([
    ...groupEvents(events),
    ...projectEvents(projectInfos, new Date(), storedProjectKeys(events)),
  ]);

  return new Response(buildRss(rows), {
    headers: {
      "Content-Type": "application/rss+xml; charset=utf-8",
      "Cache-Control": "public, max-age=300",
    },
  });
}
