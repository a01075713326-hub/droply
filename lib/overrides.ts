import fs from "node:fs";
import path from "node:path";

/* Hand-written content per project, kept in data/overrides.json.
   sync.js never touches that file, so this text survives every sync.
   Server-only (uses fs): import it from server components, not client ones. */

export type ProjectOverride = {
  /** Override the primary official website shown on the project page. */
  website?: string;
  /** Override the primary claim/action URL shown on the project page. */
  claimUrl?: string;
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