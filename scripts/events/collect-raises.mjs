// scripts/events/collect-raises.mjs
// Funding collector: DeFiLlama /raises -> data/events.json (type "funding").
// Standalone, does not touch sync.js.
//
// Usage:
//   node scripts/events/collect-raises.mjs        (last 120 days)
//   node scripts/events/collect-raises.mjs 365    (last 365 days)

import {
  slugify,
  makeId,
  loadEvents,
  saveEvents,
  mergeEvents,
  EVENTS_FILE,
} from "./lib.mjs";

const RAISES_URL = "https://api.llama.fi/raises";
const DAYS = Number(process.argv[2]) > 0 ? Number(process.argv[2]) : 120;
const SOURCE = "defillama-raises";

async function fetchRaises() {
  const res = await fetch(RAISES_URL, {
    headers: {
      Accept: "application/json",
      "User-Agent": "Droply-Events/1.0",
    },
  });
  if (!res.ok) throw new Error(`DeFiLlama /raises HTTP ${res.status}`);

  const data = await res.json();
  const list = Array.isArray(data) ? data : data?.raises;
  if (!Array.isArray(list)) {
    throw new Error(
      "Unexpected /raises response, top-level keys: " +
        Object.keys(data || {}).join(", ")
    );
  }
  return list;
}

function toMs(ts) {
  const n = Number(ts);
  if (!n) return null;
  return n > 1e12 ? n : n * 1000; // accept seconds or milliseconds
}

function toEvent(r) {
  const name = r?.name;
  const ms = toMs(r?.date);
  if (!name || !ms) return null;

  const slug = slugify(name);
  if (!slug) return null;

  const date = new Date(ms);
  const day = date.toISOString().slice(0, 10);

  // DeFiLlama reports amount in millions of USD
  const amountM = typeof r.amount === "number" ? r.amount : null;
  const leadInvestors = Array.isArray(r.leadInvestors) ? r.leadInvestors : [];
  const otherInvestors = Array.isArray(r.otherInvestors) ? r.otherInvestors : [];

  const round = r.round || "";
  const amountText = amountM != null ? `$${amountM}M` : "undisclosed amount";
  const title = `${name} raised ${amountText}${round ? ` (${round})` : ""}`;

  return {
    id: makeId(["funding", slug, day, round]),
    type: "funding",
    project: name,
    slug,
    date: date.toISOString(),
    title,
    url: r.source || "https://defillama.com/raises",
    source: SOURCE,
    data: {
      round,
      amountUsd: amountM != null ? Math.round(amountM * 1e6) : null,
      valuationUsd:
        typeof r.valuation === "number" ? Math.round(r.valuation * 1e6) : null,
      leadInvestors,
      otherInvestors,
      chains: Array.isArray(r.chains) ? r.chains : [],
      sector: r.sector || "",
      category: r.category || "",
    },
  };
}

async function main() {
  console.log("Funding collector: fetching DeFiLlama /raises ...");
  const raises = await fetchRaises();
  console.log(`Received ${raises.length} raises`);

  if (raises[0]) {
    console.log("Fields on first record: " + Object.keys(raises[0]).join(", "));
  }

  const cutoff = Date.now() - DAYS * 86400000;
  const incoming = raises
    .map(toEvent)
    .filter(Boolean)
    .filter((e) => new Date(e.date).getTime() >= cutoff);

  console.log(`In the last ${DAYS} days: ${incoming.length}`);

  const existing = await loadEvents();
  const { events, added } = mergeEvents(existing, incoming);
  await saveEvents(events);

  console.log("");
  console.log("=================================");
  console.log("Droply events: funding");
  console.log("=================================");
  console.log(`New events added:  ${added}`);
  console.log(`Total in store:    ${events.length}`);
  console.log(`File:              ${EVENTS_FILE}`);
  console.log("=================================");
  console.log("");
  console.log("Latest funding events:");

  const latest = events.filter((e) => e.type === "funding").slice(0, 15);
  for (const e of latest) {
    const day = e.date.slice(0, 10);
    const amt =
      e.data.amountUsd != null ? `$${(e.data.amountUsd / 1e6).toFixed(1)}M` : "n/a";
    const lead = e.data.leadInvestors.slice(0, 2).join(", ") || "-";
    console.log(`${day} | ${e.project} | ${e.data.round || "-"} | ${amt} | ${lead}`);
  }
  console.log("");
}

main().catch((err) => {
  console.error("Funding collector failed:", err?.message || err);
  process.exitCode = 1;
});
