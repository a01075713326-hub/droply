import type { Project } from "@/data/projects";

/** A hub page is created only when a chain/category has at least this many projects. */
export const HUB_MIN = 3;
export const SITE_URL = "https://droply.digital";

export type Hub = { slug: string; name: string; items: Project[] };

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

/** Values that are not real chains/categories: no hub page for them. */
const SKIP_NAMES = new Set([
  "multiple",
  "other",
  "ownchain",
  "unknown",
  "tba",
  "tbd",
  "n/a",
  "none",
]);

/** "Solana Ecosystem" and "Solana" become one hub. */
function cleanName(raw: string): string {
  return raw.trim().replace(/\s+ecosystem$/i, "").trim();
}

function groupBy(
  projects: Project[],
  pick: (p: Project) => string | undefined
): Hub[] {
  const map = new Map<string, Hub>();
  for (const p of projects) {
    const raw = cleanName(pick(p) || "");
    if (SKIP_NAMES.has(raw.toLowerCase())) continue;
    const slug = slugify(raw);
    if (!slug) continue;
    let hub = map.get(slug);
    if (!hub) {
      hub = { slug, name: raw, items: [] };
      map.set(slug, hub);
    }
    hub.items.push(p);
  }
  return Array.from(map.values())
    .filter((h) => h.items.length >= HUB_MIN)
    .sort(
      (a, b) => b.items.length - a.items.length || a.name.localeCompare(b.name)
    );
}

export function getChainHubs(projects: Project[]): Hub[] {
  return groupBy(projects, (p) => p.chain);
}

export function getCategoryHubs(projects: Project[]): Hub[] {
  return groupBy(projects, (p) => p.category);
}

export function getLiveProjects(projects: Project[]): Project[] {
  return projects.filter((p) => p.status === "Live" || p.isLive === true);
}

const STATUS_ORDER = ["Live", "Upcoming", "Potential", "Confirmed"];

function statusPart(items: Project[]): string {
  const parts: string[] = [];
  for (const s of STATUS_ORDER) {
    const n = items.filter((p) => p.status === s).length;
    if (n > 0) parts.push(`${n} ${s.toLowerCase()}`);
  }
  return parts.join(", ");
}

function difficultySentence(items: Project[]): string {
  const counts = new Map<string, number>();
  let total = 0;
  for (const p of items) {
    const d = (p.difficulty || "").trim();
    if (!d) continue;
    total += 1;
    counts.set(d, (counts.get(d) || 0) + 1);
  }
  if (total < HUB_MIN) return "";
  let bestName = "";
  let bestCount = 0;
  for (const [d, n] of Array.from(counts.entries())) {
    if (n > bestCount) {
      bestName = d;
      bestCount = n;
    }
  }
  if (!bestName) return "";
  return `Of ${total} projects with a difficulty rating, ${bestCount} are rated ${bestName.toLowerCase()}.`;
}

function namesSentence(items: Project[]): string {
  const rank = (s: string) => {
    const i = STATUS_ORDER.indexOf(s);
    return i === -1 ? STATUS_ORDER.length : i;
  };
  const sorted = [...items].sort((a, b) => rank(a.status) - rank(b.status));
  const names = sorted.slice(0, 3).map((p) => p.name);
  if (names.length === 0) return "";
  if (names.length === 1) return `Includes ${names[0]}.`;
  const last = names[names.length - 1];
  return `Includes ${names.slice(0, -1).join(", ")} and ${last}.`;
}

/** Short intro built only from the data we actually have. */
export function describeHub(
  kind: "chain" | "category" | "live",
  name: string,
  items: Project[]
): string {
  const n = items.length;
  const noun = n === 1 ? "airdrop" : "airdrops";
  const sp = statusPart(items);
  const spText = sp ? ` (${sp})` : "";

  if (kind === "live" && n === 0) {
    return "No airdrops are marked live at the moment. Check the full list for upcoming and potential drops.";
  }

  let first: string;
  if (kind === "chain") {
    first = `Droply tracks ${n} ${name} ${noun}${spText}.`;
  } else if (kind === "category") {
    first = `Droply tracks ${n} ${noun} in the ${name} category${spText}.`;
  } else {
    first = `${n} ${noun} ${n === 1 ? "is" : "are"} marked live right now.`;
  }

  return [first, difficultySentence(items), namesSentence(items)]
    .filter(Boolean)
    .join(" ");
}

export function clip(text: string, max = 155): string {
  if (text.length <= max) return text;
  return text.slice(0, max - 3).trimEnd() + "...";
}

export function breadcrumbLd(trail: { name: string; path: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: trail.map((t, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: t.name,
      item: SITE_URL + t.path,
    })),
  };
}

// ---------- Segment lists: /airdrops/confirmed, /airdrops/points, /airdrops/no-token ----------

export type SegmentKey = "confirmed" | "points" | "no-token";

export type Segment = {
  path: string;
  title: string;
  kicker: string;
  pick: (projects: Project[]) => Project[];
};

export function getConfirmedAirdrops(projects: Project[]): Project[] {
  return projects.filter((p) => p.status === "Confirmed");
}

export function getPointsPrograms(projects: Project[]): Project[] {
  return projects.filter((p) =>
    (p.event || "").split(",").some((e) => e.trim().toLowerCase() === "points")
  );
}

/** Same rule as the "Pre-token" badge on project pages. */
export function getNoTokenProjects(projects: Project[]): Project[] {
  return projects.filter((p) => {
    const stage = (p as any).lifeCycle;
    return stage === "funding" || stage === "scheduled";
  });
}

export const SEGMENTS: Record<SegmentKey, Segment> = {
  confirmed: {
    path: "/airdrops/confirmed",
    title: "Confirmed Airdrops",
    kicker: "CONFIRMED",
    pick: getConfirmedAirdrops,
  },
  points: {
    path: "/airdrops/points",
    title: "Points Programs",
    kicker: "POINTS",
    pick: getPointsPrograms,
  },
  "no-token": {
    path: "/airdrops/no-token",
    title: "No-Token Airdrops",
    kicker: "PRE-TOKEN",
    pick: getNoTokenProjects,
  },
};

/** Short intro for a segment page, built only from the data we have. */
export function describeSegment(key: SegmentKey, items: Project[]): string {
  const n = items.length;
  if (n === 0) {
    return "Nothing matches this list at the moment. Check the full list for other drops.";
  }
  const sp = statusPart(items);
  const spText = sp ? ` (${sp})` : "";

  let first: string;
  if (key === "confirmed") {
    first = `Droply tracks ${n} confirmed ${n === 1 ? "airdrop" : "airdrops"}.`;
  } else if (key === "points") {
    first = `Droply tracks ${n} points ${n === 1 ? "program" : "programs"}${spText}.`;
  } else {
    first = `${n} tracked ${n === 1 ? "project is" : "projects are"} listed at a pre-token stage, before any token launch${spText}. Token status can change, so check the official channels.`;
  }

  return [first, difficultySentence(items), namesSentence(items)]
    .filter(Boolean)
    .join(" ");
}

/** Links to list hubs (live + segments) that are big enough to be indexed. Used on the home page and in the footer. */
export function getHubLinks(projects: Project[]): { href: string; label: string; count: number }[] {
  const links = [
    { href: "/airdrops/live", label: "Live airdrops", count: getLiveProjects(projects).length },
    ...(Object.keys(SEGMENTS) as SegmentKey[]).map((k) => ({
      href: SEGMENTS[k].path,
      label: SEGMENTS[k].title,
      count: SEGMENTS[k].pick(projects).length,
    })),
  ];
  return links.filter((l) => l.count >= HUB_MIN);
}

/** JSON-LD ItemList for a list page: the projects shown on it (capped to keep the payload small). */
export function itemListLd(name: string, path: string, items: Project[], max = 50) {
  const list = items.slice(0, max);
  return {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name,
    url: SITE_URL + path,
    numberOfItems: list.length,
    itemListElement: list.map((p, i) => ({
      "@type": "ListItem",
      position: i + 1,
      url: `${SITE_URL}/project/${encodeURIComponent(p.slug)}`,
      name: p.name,
    })),
  };
}
