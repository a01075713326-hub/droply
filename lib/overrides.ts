import fs from "node:fs";
import path from "node:path";

/* Hand-written content per project, kept in data/overrides.json.
   sync.js never touches that file, so this text survives every sync.
   Server-only (uses fs): import it from server components, not client ones. */

export type ProjectOverride = {
  /** Short line for the hero (replaces the generic source description). */
  tagline?: string;
  /** Your own overview. Also used as the meta description. */
  summary?: string;
  /** Real risks, one short sentence each. */
  risks?: string[];
  /** Nuances of the steps that the source guide does not mention. */
  notes?: string[];
  /** Your own step-by-step guide. When present it replaces the steps parsed from the source. */
  steps?: string[];
  /** YYYY-MM-DD, when you last reviewed this project. */
  updatedAt?: string;

  /* Link overrides. Each one, when set, replaces the value that came from
     the source API (CryptoRank/Airdrops.io/AirdropAlert) for that project,
     for cases where the scraped link is wrong, dead, or missing. Leave a
     field out to keep using whatever the source provided. */
  /** Official project website. */
  website?: string;
  /** Airdrop / claim / participate page (e.g. the actual game or app URL). */
  claimUrl?: string;
  /** Docs or guide link. */
  docs?: string;
  /** Whitepaper link. */
  whitepaper?: string;
  /** X (Twitter) profile link. */
  x?: string;
  /** Telegram link. */
  telegram?: string;
  /** Discord invite link. */
  discord?: string;

  /** Fix a specific broken/wrong link inside the scraped guide text (steps
      and task instructions), without rewriting the whole guide. Key: the
      exact URL as it appears in the scraped text (from CryptoRank/
      Airdrops.io/AirdropAlert). Value: the correct URL to use instead. */
  linkFixes?: Record<string, string>;
};

export function getOverride(slug: string): ProjectOverride | undefined {
  try {
    const file = path.join(process.cwd(), "data", "overrides.json");
    const raw = fs.readFileSync(file, "utf8").replace(/^\uFEFF/, "");
    const data = JSON.parse(raw) as Record<string, ProjectOverride>;
    return Object.prototype.hasOwnProperty.call(data, slug) ? data[slug] : undefined;
  } catch {
    return undefined;
  }
}

/* Indexing rule: a project page is shown to search engines only when it has
   something of our own on it. Every other page stays open for visitors but
   gets noindex and is left out of the sitemap. */

/** CryptoRank projects that carry task data are indexed even without a hand-written review. Set to false to index only reviewed projects. */
const INDEX_CRYPTORANK_WITH_TASKS = true;

export function hasOwnContent(o?: ProjectOverride): boolean {
  if (!o) return false;
  return Boolean(o.summary || o.steps?.length || o.risks?.length || o.notes?.length);
}

export function isIndexable(p: { slug: string; source?: string; tasks?: unknown[] }): boolean {
  if (hasOwnContent(getOverride(p.slug))) return true;
  if (
    INDEX_CRYPTORANK_WITH_TASKS &&
    String(p.source || "").toLowerCase().includes("cryptorank") &&
    Array.isArray(p.tasks) &&
    p.tasks.length > 0
  ) {
    return true;
  }
  return false;
}
