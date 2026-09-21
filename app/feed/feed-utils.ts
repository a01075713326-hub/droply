// Helpers for /feed. No React or Next imports here, so the logic can be tested on its own.

export type RawEvent = {
  id: string;
  type: string;
  project?: string;
  slug?: string;
  date?: string;
  title?: string;
  url?: string;
  source?: string;
  data?: {
    exchange?: string;
    region?: string;
    ticker?: string;
    tickers?: string[];
    status?: string;
    airdropRelated?: boolean;
    originalTitle?: string;
    // Events written by collect-projects.mjs (source "droply-projects"):
    kind?: string;
    from?: string;
    to?: string;
  };
  firstSeenAt?: string;
};

export type ProjectRef = { slug: string; name: string };

export type Row = {
  key: string;
  date: string;
  type: string;
  exchange: string;
  region: string;
  /** Title shown in the feed (English). */
  title: string;
  /** Title exactly as the exchange published it. */
  original: string;
  /** English text used to look for project names. Empty when the title is not English. */
  matchText: string;
  /** External link (exchange announcement). Empty for project rows. */
  url: string;
  /** Internal link, used by project rows. */
  internalHref?: string;
  /** Short label shown before the title (project rows). */
  badge?: string;
  airdrop: boolean;
  tickers: { ticker: string; status: string }[];
};

// Upbit publishes in Korean. The market list looks like "(KRW, BTC, USDT 마켓)" or "BTC, USDT 마켓 ...".
const UPBIT_MARKETS_RE = /((?:KRW|BTC|USDT)(?:\s*,\s*(?:KRW|BTC|USDT))*)\s*마켓/;

function upbitTitle(row: Row): string {
  if (row.tickers.length === 0) return row.original;
  const list = row.tickers.map((t) => t.ticker).join(", ");
  const m = row.original.match(UPBIT_MARKETS_RE);
  if (!m) return `New listing: ${list}`;
  const markets = m[1].replace(/\s*,\s*/g, ", ");
  const noun = markets.includes(",") ? "markets" : "market";
  return `New listing: ${list} (${markets} ${noun})`;
}

// Events written by scripts/events/collect-projects.mjs about the projects Droply tracks.
export const PROJECT_SOURCE = "droply-projects";

function storedProjectRow(e: RawEvent): Row {
  const kind = String(e.data?.kind ?? "");
  const to = String(e.data?.to ?? "");
  const badge =
    kind === "new" ? "New" : kind === "status" ? to || "Status" : kind === "distribution" ? "Distribution" : "Update";
  const title = e.title || "";
  return {
    key: e.id,
    date: e.date || "",
    type: "project",
    exchange: "Droply",
    region: "",
    title,
    original: title,
    matchText: "",
    url: "",
    internalHref: e.slug ? `/project/${encodeURIComponent(e.slug)}` : undefined,
    badge,
    airdrop: false,
    tickers: [],
  };
}

// "new:slug" / "status:slug" for every stored event. The live rows built from the current project
// list skip those, because the stored event is the richer one (it knows what the status was before).
export function storedProjectKeys(events: RawEvent[]): Set<string> {
  const keys = new Set<string>();
  for (const e of events) {
    if (e.source !== PROJECT_SOURCE || !e.slug || !e.data?.kind) continue;
    keys.add(`${e.data.kind}:${e.slug}`);
  }
  return keys;
}

export function sortRows(rows: Row[]): Row[] {
  return rows.sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
}

// One announcement can produce several events (one per ticker) with the same URL.
// Show it as a single row with a chip per ticker.
export function groupEvents(events: RawEvent[]): Row[] {
  const rows = new Map<string, Row>();
  for (const e of events) {
    if (e.source === PROJECT_SOURCE) {
      rows.set(e.id, storedProjectRow(e));
      continue;
    }
    const key = e.url || e.id;
    const ticker = (e.data?.ticker || e.project || "").trim();
    const status = e.data?.status || "announced";
    const existing = rows.get(key);
    if (existing) {
      if (ticker && !existing.tickers.some((t) => t.ticker === ticker)) {
        existing.tickers.push({ ticker, status });
      }
      if (e.data?.airdropRelated) existing.airdrop = true;
      continue;
    }
    const original = e.data?.originalTitle || e.title || "";
    rows.set(key, {
      key,
      date: e.date || "",
      type: e.type || "other",
      exchange: e.data?.exchange || "Other",
      region: e.data?.region && e.data.region !== "global" ? e.data.region : "",
      title: original,
      original,
      matchText: "",
      url: e.url || "",
      airdrop: Boolean(e.data?.airdropRelated),
      tickers: ticker ? [{ ticker, status }] : [],
    });
  }

  const list = Array.from(rows.values());
  for (const r of list) {
    if (r.exchange === "Upbit") {
      r.title = upbitTitle(r);
    } else {
      r.matchText = r.original;
    }
  }
  return list;
}

function toSlug(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function normalize(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

// Soft match between an exchange row and Droply projects. Two rules, both deliberately strict:
//   A. a ticker turned into a slug equals a project slug ("HEMI" -> "hemi");
//   B. the project name (4+ Latin characters) appears as whole words in the English title
//      ("Introducing OpenGradient (OPG) ..." -> "OpenGradient").
// A row without a match is still shown, it just has no link.
export function matchProjects(row: Row, projects: ProjectRef[], limit = 3): ProjectRef[] {
  const tickerSlugs = new Set(row.tickers.map((t) => toSlug(t.ticker)).filter(Boolean));
  const text = row.matchText ? ` ${normalize(row.matchText)} ` : "";
  const found: ProjectRef[] = [];
  const seen = new Set<string>();

  for (const p of projects) {
    if (!p.slug || seen.has(p.slug)) continue;
    let hit = tickerSlugs.has(p.slug.toLowerCase());
    if (!hit && text) {
      const name = normalize(p.name || "");
      hit = name.length >= 4 && text.includes(` ${name} `);
    }
    if (hit) {
      seen.add(p.slug);
      found.push({ slug: p.slug, name: p.name });
      if (found.length >= limit) break;
    }
  }
  return found;
}

// ---------------------------------------------------------------------------------------
// Events about the projects Droply tracks, computed on the fly from the project list.
// Nothing is stored, so there is no history: only what the current data says.
// ---------------------------------------------------------------------------------------

export type ProjectInfo = {
  slug: string;
  name: string;
  event?: string;
  status?: string;
  chain?: string;
  /** Sync writes status_updated_at here, or the nearest future task end / distribution date if there is one. */
  date?: string;
  firstSeenAt?: string;
  distributeDate?: string;
  tasks?: { title: string; endDate?: string }[];
};

const DAY_MS = 24 * 60 * 60 * 1000;
const NEW_WINDOW_DAYS = 14;
const STATUS_WINDOW_DAYS = 30;
const DEADLINE_WINDOW_DAYS = 30;
// One sync run stamps every project it adds with the same firstSeenAt. A run that adds this many
// or more looks like an initial import or a reset, not real news, so it is not shown.
const IMPORT_BATCH_SIZE = 15;

function isoDay(s?: string): string {
  return s && /^\d{4}-\d{2}-\d{2}/.test(s) ? s.slice(0, 10) : "";
}

function daysBetween(fromDay: string, toDay: string): number {
  return Math.round((Date.parse(toDay) - Date.parse(fromDay)) / DAY_MS);
}

export function projectEvents(
  projects: ProjectInfo[],
  now: Date = new Date(),
  skip: Set<string> = new Set()
): Row[] {
  const today = now.toISOString().slice(0, 10);
  const rows: Row[] = [];

  const batch = new Map<string, number>();
  for (const p of projects) {
    if (p.firstSeenAt) batch.set(p.firstSeenAt, (batch.get(p.firstSeenAt) ?? 0) + 1);
  }

  const make = (p: ProjectInfo, kind: string, date: string, title: string, badge: string): Row => ({
    key: `project:${kind}:${p.slug}:${date}`,
    date,
    type: "project",
    exchange: "Droply",
    region: "",
    title,
    original: title,
    matchText: "",
    url: "",
    internalHref: `/project/${encodeURIComponent(p.slug)}`,
    badge,
    airdrop: false,
    tickers: [],
  });

  for (const p of projects) {
    if (!p.slug || !p.name) continue;

    // 1. New on Droply (firstSeenAt is set once, when the project first appears in a sync)
    const seen = isoDay(p.firstSeenAt);
    if (seen && p.firstSeenAt && !skip.has(`new:${p.slug}`) && (batch.get(p.firstSeenAt) ?? 0) < IMPORT_BATCH_SIZE) {
      const age = daysBetween(seen, today);
      if (age >= 0 && age <= NEW_WINDOW_DAYS) {
        const what = [p.event, p.chain].filter(Boolean).join(", ");
        rows.push(make(p, "new", p.firstSeenAt, `${p.name} added to Droply${what ? ` (${what})` : ""}`, "New"));
      }
    }

    // 2. Status: only meaningful statuses, only when `date` is a past date (a status update),
    //    and not when a real distribution date has replaced it.
    const statusDay = isoDay(p.date);
    if (
      !p.distributeDate &&
      !skip.has(`status:${p.slug}`) &&
      statusDay &&
      statusDay <= today &&
      p.status &&
      p.status !== "Potential" &&
      daysBetween(statusDay, today) <= STATUS_WINDOW_DAYS
    ) {
      rows.push(make(p, "status", statusDay, `${p.name}: ${p.status}${p.event ? ` (${p.event})` : ""}`, p.status));
    }

    // 3. Nearest task deadline in the next month
    let nearest: { day: string; title: string } | null = null;
    for (const t of p.tasks ?? []) {
      const day = isoDay(t.endDate);
      if (!day || day < today || daysBetween(today, day) > DEADLINE_WINDOW_DAYS) continue;
      if (!nearest || day < nearest.day) nearest = { day, title: t.title || "" };
    }
    if (nearest) {
      rows.push(
        make(p, "deadline", nearest.day, `${p.name}: task ends${nearest.title ? ` - ${nearest.title}` : ""}`, "Deadline")
      );
    }

    // 4. Real distribution date (rare): from a week ago to two months ahead
    const dist = isoDay(p.distributeDate);
    if (dist) {
      const delta = daysBetween(today, dist);
      if (delta >= -7 && delta <= 60) {
        rows.push(make(p, "distribution", dist, `${p.name}: distribution date`, "Distribution"));
      }
    }
  }
  return rows;
}
