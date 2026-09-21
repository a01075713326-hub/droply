import { readFile } from "node:fs/promises";
import path from "node:path";

type AnyEvent = Record<string, any>;

export type TimelineItem = { key: string; date: string; dateLabel: string; label: string };

export async function readEvents(): Promise<AnyEvent[]> {
  try {
    const raw = await readFile(path.join(process.cwd(), "data", "events.json"), "utf8");
    const j = JSON.parse(raw);
    if (Array.isArray(j)) return j as AnyEvent[];
    if (j && Array.isArray(j.events)) return j.events as AnyEvent[];
  } catch {
    // no events file yet
  }
  return [];
}

function fmtDate(iso: string): string {
  const d = new Date(iso);
  if (isNaN(d.getTime())) return iso;
  return new Intl.DateTimeFormat("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  }).format(d);
}

function labelFor(e: AnyEvent): string {
  const d = (e.data || {}) as AnyEvent;
  if (d.kind === "new") return "Added to Droply";
  if (d.kind === "status" && (d.from || d.to)) {
    return "Status changed: " + (d.from || "?") + " -> " + (d.to || "?");
  }
  return (e.title as string) || "Update";
}

export async function getProjectTimeline(
  slug: string,
  firstSeenAt?: string
): Promise<TimelineItem[]> {
  const events = await readEvents();
  const mine = events.filter((e) => e.type === "project" && e.slug === slug);

  const items: TimelineItem[] = mine
    .map((e, i) => {
      const date: string = (e.date as string) || (e.firstSeenAt as string) || "";
      return {
        key: (e.id as string) || slug + "-" + i,
        date,
        dateLabel: date ? fmtDate(date) : "",
        label: labelFor(e),
      };
    })
    .filter((x) => x.date);

  const hasNew = mine.some((e) => (e.data || {}).kind === "new");
  if (!hasNew && firstSeenAt) {
    items.push({
      key: "synthetic-new",
      date: firstSeenAt,
      dateLabel: fmtDate(firstSeenAt),
      label: "Added to Droply",
    });
  }

  items.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
  return items;
}