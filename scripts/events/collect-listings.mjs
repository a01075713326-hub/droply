// scripts/events/collect-listings.mjs  (v3)
// Exchange announcements -> data/events.json (type "listing"), one event per ticker.
// Sources (public, keyless, unofficial endpoints, each one isolated):
//   Binance  "New Cryptocurrency Listing" catalog
//   OKX      announcements-new-listings (region-dependent, see data.region)
//   Bybit    announcements, type new_crypto
//   Upbit    trading notices (only "new trading support" notices are kept)
//
// Skipped by default: futures / perpetual / TradFi / stock-token / dividend
// notices and promo campaigns (token splash, prize pools, giveaways).
// Use --all to keep the futures-type noise as well.
//
// Usage:
//   node scripts/events/collect-listings.mjs
//   node scripts/events/collect-listings.mjs --all

import {
  slugify,
  makeId,
  loadEvents,
  saveEvents,
  mergeEvents,
  EVENTS_FILE,
} from "./lib.mjs";

const INCLUDE_ALL = process.argv.includes("--all");
const SOURCE = "exchange-announcements";

const NOISE_RE =
  /perpetual|futures|delivery contract|tradfi|bstocks|\boptions?\b|\bmargin\b|leverage|dividend|token splash|prize pool|giveaway|trading competition|stock trading|tokenized securit|collateral assets|trading bots/i;
const AIRDROP_RE = /airdrop|hodler|launchpool|megadrop/i;
// Airdrop programs (as opposed to plain listings) get their own event type.
const PROGRAM_RE = /hodler|launchpool|megadrop/i;
const QUOTE = new Set(["KRW", "BTC", "USDT", "USDC", "USD", "EUR", "JPY", "BUSD", "FDUSD"]);

async function getJson(url) {
  const res = await fetch(url, {
    headers: {
      "User-Agent": "Mozilla/5.0 (compatible; Droply-Events/1.0)",
      Accept: "application/json",
    },
    signal: AbortSignal.timeout(20000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

// Each fetcher returns [{ exchange, sourceId, title, url, ms }]

// Catalog 48 is mostly futures notices, so spot listings and HODLer posts sit several
// pages deep (roughly one page per 2-4 weeks). Default: 3 pages. --deep: 10 pages
// (back to about January), meant for the first backfill.
const BINANCE_PAGES = process.argv.includes("--deep") ? 10 : 3;

async function binancePage(page, size) {
  const d = await getJson(
    `https://www.binance.com/bapi/composite/v1/public/cms/article/list/query?type=1&catalogId=48&pageNo=${page}&pageSize=${size}`
  );
  const articles = d?.data?.catalogs?.[0]?.articles;
  if (!Array.isArray(articles)) throw new Error("unexpected response shape");
  return articles.map((a) => ({
    exchange: "Binance",
    sourceId: String(a.id),
    title: String(a.title || ""),
    url: `https://www.binance.com/en/support/announcement/detail/${a.code}`,
    ms: Number(a.releaseDate),
  }));
}

async function binance() {
  // Binance rejects page sizes it does not like with HTTP 400, so step down.
  let all = null;
  let size = 0;
  let lastErr;
  for (const s of [20, 15, 10, 5]) {
    try {
      all = await binancePage(1, s);
      size = s;
      break;
    } catch (e) {
      lastErr = e;
    }
  }
  if (!all) throw lastErr;

  for (let page = 2; page <= BINANCE_PAGES; page++) {
    await new Promise((r) => setTimeout(r, 300));
    try {
      all.push(...(await binancePage(page, size)));
    } catch (e) {
      console.log(`  Binance: page ${page} failed (${e.message}), keeping the pages fetched so far`);
      break;
    }
  }

  // New posts can shift pages between requests, so drop duplicates.
  const seen = new Set();
  return all.filter((a) => !seen.has(a.sourceId) && seen.add(a.sourceId));
}

async function okx() {
  const d = await getJson(
    "https://www.okx.com/api/v5/support/announcements?annType=announcements-new-listings&page=1"
  );
  const details = d?.data?.[0]?.details;
  if (!Array.isArray(details)) throw new Error("unexpected response shape");
  return details.map((a) => ({
    exchange: "OKX",
    sourceId: String(a.url),
    title: String(a.title || ""),
    url: a.url,
    ms: Number(a.pTime),
  }));
}

async function bybit() {
  const d = await getJson(
    "https://api.bybit.com/v5/announcements/index?locale=en-US&type=new_crypto&limit=50"
  );
  const list = d?.result?.list;
  if (!Array.isArray(list)) throw new Error("unexpected response shape");
  return list.map((a) => ({
    exchange: "Bybit",
    sourceId: String(a.url),
    title: String(a.title || ""),
    url: a.url,
    ms: Number(a.publishTime || a.dateTimestamp),
  }));
}

async function upbit() {
  const d = await getJson(
    "https://api-manager.upbit.com/api/v1/announcements?os=web&page=1&per_page=30&category=trade"
  );
  const notices = d?.data?.notices;
  if (!Array.isArray(notices)) throw new Error("unexpected response shape");
  return notices
    .filter((n) => /신규\s*거래지원/.test(String(n.title || ""))) // "new trading support"
    .map((n) => ({
      exchange: "Upbit",
      sourceId: String(n.id),
      title: String(n.title || ""),
      url: `https://upbit.com/service_center/notice?id=${n.id}`,
      ms: Date.parse(n.listed_at),
    }));
}

function extractTickers(title, exchange) {
  const set = new Set();
  const add = (t) => {
    if (t && !QUOTE.has(t) && !/^\d+$/.test(t)) set.add(t);
  };
  // "(BICO, BMT, NIL, GWEI)"
  for (const m of title.matchAll(/\(([A-Z0-9]{2,15}(?:\s*,\s*[A-Z0-9]{2,15})+)\)/g))
    m[1].split(/\s*,\s*/).forEach(add);
  // "(FOO)"
  for (const m of title.matchAll(/\(([A-Z0-9]{2,15})\)/g)) add(m[1]);
  // "FOO/USDT"
  for (const m of title.matchAll(/\b([A-Z0-9]{2,15})\/(?:USDT|USDC|USD|EUR|BTC|KRW)\b/g))
    add(m[1]);
  // "OKX to list KAT and OKB on spot" / "list AAA, BBB on ..."
  for (const m of title.matchAll(/\blist\s+([A-Z0-9]{2,15}(?:(?:\s*,\s*|\s+and\s+)[A-Z0-9]{2,15})*)\s+on\b/g))
    m[1].split(/\s*,\s*|\s+and\s+/).forEach(add);
  // Binance sometimes lists tokens with non-Latin tickers, e.g. "Will List XYZ (牛来)"
  if (exchange === "Binance") {
    for (const m of title.matchAll(/\(([\p{L}\p{N}]{2,15})\)/gu)) add(m[1]);
  }
  return [...set];
}

// Upbit amends notices in place by appending a last parenthetical such as
//   "(JPYC 거래지원 개시 시점 추가 변경 안내)"  -> start time changed, for JPYC only
//   "(헤미(HEMI) 거래지원 취소 안내)"          -> trading support cancelled, for HEMI only
//   "(거래지원 개시 시점 변경 안내)"           -> no ticker named, applies to all tickers
const AMEND_TAIL_RE =
  /\(((?:[^()]|\([^()]*\))*?)\s*거래지원\s*(취소[^()]*|개시\s*시점[^()]*)\)\s*$/u;

function statusFor(title, ticker) {
  const m = title.match(AMEND_TAIL_RE);
  if (!m) return "announced";
  const named = [...m[1].matchAll(/[A-Z0-9]{2,15}/g)].map((x) => x[0]);
  const kind = /취소/.test(m[2]) ? "cancelled" : /변경|연기/.test(m[2]) ? "updated" : "announced";
  if (named.length === 0 || (ticker && named.includes(ticker))) return kind;
  return "announced";
}

function toEvents(raw) {
  if (!raw.title || !Number.isFinite(raw.ms)) return [];
  if (!INCLUDE_ALL && NOISE_RE.test(raw.title)) return [];

  const tickers = extractTickers(raw.title, raw.exchange);
  // Binance posts without a ticker are pair/notice/promo noise, not new tokens.
  if (!INCLUDE_ALL && raw.exchange === "Binance" && tickers.length === 0 && !AIRDROP_RE.test(raw.title)) return [];
  const list = tickers.length ? tickers : [""];
  const region = raw.exchange === "OKX" && /\/en-eu\//.test(raw.url) ? "EEA" : "global";

  return list.map((t) => ({
    id: makeId(["listing", raw.exchange, raw.sourceId, t]),
    type: PROGRAM_RE.test(raw.title) ? "airdrop" : "listing",
    project: t,
    slug: t ? slugify(t) || t.toLowerCase() : "",
    date: new Date(raw.ms).toISOString(),
    title: `${raw.exchange}: ${raw.title}`,
    url: raw.url,
    source: SOURCE,
    data: {
      exchange: raw.exchange,
      region,
      ticker: t,
      tickers,
      status: statusFor(raw.title, t),
      airdropRelated: AIRDROP_RE.test(raw.title),
      originalTitle: raw.title,
    },
  }));
}

async function main() {
  console.log("Listings collector: polling exchanges ...");
  const fetchers = { Binance: binance, OKX: okx, Bybit: bybit, Upbit: upbit };
  const names = Object.keys(fetchers);
  const results = await Promise.allSettled(names.map((n) => fetchers[n]()));

  const incoming = [];
  let okCount = 0;

  results.forEach((r, i) => {
    const name = names[i];
    if (r.status === "fulfilled") {
      okCount++;
      const events = r.value.flatMap(toEvents);
      incoming.push(...events);
      console.log(`  ${name}: ${r.value.length} announcements, ${events.length} events kept`);
    } else {
      console.log(`  ${name}: FAILED (${r.reason?.message || r.reason})`);
    }
  });

  if (okCount === 0) throw new Error("all exchanges failed");

  const existing = await loadEvents();
  const { events, added } = mergeEvents(existing, incoming);
  await saveEvents(events);

  console.log("");
  console.log("=================================");
  console.log("Droply events: listings");
  console.log("=================================");
  console.log(`Exchanges OK:      ${okCount}/${names.length}`);
  console.log(`New events added:  ${added}`);
  console.log(`Total in store:    ${events.length}`);
  console.log(`File:              ${EVENTS_FILE}`);
  console.log("=================================");
  console.log("");
  console.log("Latest listing events:");

  const latest = events.filter((e) => e.type === "listing" || e.type === "airdrop").slice(0, 25);
  for (const e of latest) {
    const day = e.date.slice(0, 10);
    const flags = [
      e.data.status !== "announced" ? e.data.status : "",
      e.data.region === "EEA" ? "EEA" : "",
      e.data.airdropRelated ? "airdrop" : "",
    ]
      .filter(Boolean)
      .join(",");
    console.log(
      `${day} | ${e.data.exchange} | ${e.data.ticker || "-"} | ${e.data.originalTitle.slice(0, 90)}${flags ? ` [${flags}]` : ""}`
    );
  }
  console.log("");
}

main().catch((err) => {
  console.error("Listings collector failed:", err?.message || err);
  process.exitCode = 1;
});
