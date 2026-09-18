export type SyncProject = {
  id: number; slug: string; name: string; symbol: string; chain: string;
  event: "Snapshot" | "TGE" | "Claim" | "Airdrop" | "Points";
  status: "Potential" | "Upcoming" | "Live" | "Confirmed"; date: string; description: string;
  funding?: string; website?: string; x?: string; logo?: string; source?: string; sourceUrl?: string; claimUrl?: string; updatedAt?: string;
};

export const SOURCE_URLS = { cryptorank: "https://cryptorank.io/drophunting", airdropsIo: "https://airdrops.io/latest/" };

export function slugify(value: string) { return value.toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "") || "project"; }

export function mapCryptoRankStatus(status: string): SyncProject["status"] {
  switch (String(status).toUpperCase()) {
    case "CONFIRMED": case "REWARD_AVAILABLE": case "DISTRIBUTED": return "Confirmed";
    case "SNAPSHOT": return "Live"; case "VERIFICATION": return "Upcoming"; default: return "Potential";
  }
}
export function mapRewardEvent(reward: string): SyncProject["event"] {
  const value = String(reward || "").toLowerCase();
  if (value.includes("point")) return "Points"; if (value.includes("snapshot")) return "Snapshot"; if (value.includes("claim")) return "Claim"; return "Airdrop";
}

export function normalizeCryptoRankActivity(item: any, index: number): SyncProject {
  const name = item?.coin?.name || item?.name || `Project ${item?.id ?? index + 1}`;
  const symbol = item?.coin?.symbol || item?.symbol || "—"; const slug = slugify(item?.coin?.key || name);
  const blockchain = item?.tasks?.flatMap((task: any) => task?.blockchains || [])?.[0]?.name;
  const dateValue = item?.rewardDate || item?.lastStatusUpdate;
  const date = dateValue ? new Date(Number(dateValue) < 10000000000 ? Number(dateValue) * 1000 : Number(dateValue)).toISOString().slice(0, 10) : "";
  const funds = (item?.coin?.funds || []).map((fund: any) => fund?.name).filter(Boolean).join(", ");
  return { id: Number(item?.id ?? index + 1), slug, name, symbol, chain: blockchain || "Multiple", event: mapRewardEvent(item?.reward), status: mapCryptoRankStatus(item?.status), date, description: `${name} drop activity tracked from CryptoRank Drophunting.`, funding: item?.coin?.totalRaise ? `$${item.coin.totalRaise}` : funds || undefined, website: item?.links?.verify || item?.links?.claim || undefined, logo: item?.coin?.images?.x150 || item?.coin?.images?.native || item?.coin?.images?.icon || undefined, claimUrl: item?.links?.claim || item?.links?.verify || undefined, source: "CryptoRank", sourceUrl: `${SOURCE_URLS.cryptorank}/${item?.key || slug}`, updatedAt: new Date().toISOString() };
}

export async function fetchCryptoRank(): Promise<SyncProject[]> {
  const key = process.env.CRYPTORANK_API_KEY; if (!key) return [];
  const url = new URL("https://api.cryptorank.io/v2/drophunting/activities"); url.searchParams.set("limit", "300"); url.searchParams.set("sortBy", "lastStatusUpdate"); url.searchParams.set("sortDirection", "DESC");
  const response = await fetch(url, { headers: { "X-Api-Key": key }, cache: "no-store" });
  if (!response.ok) throw new Error(`CryptoRank HTTP ${response.status}: ${await response.text()}`);
  const json = await response.json(); return (json.data || []).map((item: any, index: number) => normalizeCryptoRankActivity(item, index));
}

function decodeHtml(value: string) { return value.replace(/&amp;/g, "&").replace(/&#8217;|&#x27;/g, "'").replace(/&quot;/g, '"').replace(/&#039;/g, "'").replace(/&nbsp;/g, " "); }
function titleFromBlock(block: string, fallback: string) {
  const alt = block.match(/alt=["']([^"']+?)(?:\s+logo)?["']/i)?.[1];
  if (alt && alt.length < 100 && !/^(image|logo)$/i.test(alt)) return decodeHtml(alt).trim();
  const heading = block.match(/<(?:h[1-6]|strong)[^>]*>\s*([^<]{2,80})\s*<\//i)?.[1];
  return decodeHtml(heading || fallback).replace(/\s+/g, " ").trim();
}

export async function fetchAirdropsIo(): Promise<SyncProject[]> {
  const response = await fetch(SOURCE_URLS.airdropsIo, { headers: { "User-Agent": "Droply.digital public aggregator" }, cache: "no-store" });
  if (!response.ok) throw new Error(`Airdrops.io HTTP ${response.status}`);
  const html = await response.text(); const result: SyncProject[] = []; const seen = new Set<string>();
  const linkRegex = /href=["']https?:\/\/airdrops\.io\/([^"'/?#]+)\/?["'][^>]*>/gi; let match: RegExpExecArray | null;
  while ((match = linkRegex.exec(html))) {
    const slug = slugify(match[1]);
    if (!slug || seen.has(slug) || /^(latest|hot|confirmed|categories|category|blog|faq|contact|newsletter|calendar|activity|about|disclaimer|privacy|terms|login|register)$/i.test(slug)) continue;
    const block = html.slice(Math.max(0, match.index - 1200), Math.min(html.length, match.index + 2200));
    if (!/CLAIM AIRDROP|Airdrop/i.test(block)) continue;
    seen.add(slug); const name = titleFromBlock(block, match[1].replace(/-/g, " "));
    const status: SyncProject["status"] = /\bConfirmed\b/i.test(block) ? "Confirmed" : /\bEnded\b/i.test(block) ? "Potential" : /\bOngoing\b/i.test(block) ? "Live" : "Potential";
    const chain = block.match(/Chain:\s*([^<\n]{2,40})/i)?.[1]?.trim() || "Multiple";
    const image = block.match(/<img[^>]+src=["']([^"']+)["']/i)?.[1];
    result.push({ id: result.length + 1, slug, name, symbol: "—", chain, event: "Airdrop", status, date: "", description: `${name} airdrop listing aggregated from Airdrops.io.`, logo: image, source: "Airdrops.io", sourceUrl: `https://airdrops.io/${slug}/`, claimUrl: `https://airdrops.io/${slug}/`, updatedAt: new Date().toISOString() });
    if (result.length >= 150) break;
  }
  return result;
}

export function dedupeProjects(items: SyncProject[]) {
  const map = new Map<string, SyncProject>();
  for (const item of items) { const key = item.slug || slugify(item.name); const previous = map.get(key); map.set(key, previous ? { ...previous, ...item, website: item.website || previous.website, logo: item.logo || previous.logo } : item); }
  return Array.from(map.values()).map((item, index) => ({ ...item, id: index + 1 }));
}

export async function fetchAllSources() {
  const [cryptorank, airdropsIo] = await Promise.allSettled([fetchCryptoRank(), fetchAirdropsIo()]);
  const projects = dedupeProjects([...(cryptorank.status === "fulfilled" ? cryptorank.value : []), ...(airdropsIo.status === "fulfilled" ? airdropsIo.value : [])]);
  return { projects, sources: { cryptorank: cryptorank.status === "fulfilled" ? cryptorank.value.length : 0, airdropsIo: airdropsIo.status === "fulfilled" ? airdropsIo.value.length : 0, errors: [cryptorank, airdropsIo].filter((x): x is PromiseRejectedResult => x.status === "rejected").map(x => String(x.reason?.message || x.reason)) } };
}
