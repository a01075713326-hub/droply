// Pure helper (safe to import from client components).
const SKIP = new Set([
  "multiple",
  "other",
  "ownchain",
  "unknown",
  "tba",
  "tbd",
  "n/a",
  "none",
]);

/** "Robinhood Ecosystem" -> "robinhood". Returns "" for values that are not a real chain. */
export function chainSlug(raw: string | null | undefined): string {
  const name = (raw || "").trim().replace(/\s+ecosystem$/i, "").trim();
  if (!name || name.includes(",")) return "";
  if (SKIP.has(name.toLowerCase())) return "";
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}