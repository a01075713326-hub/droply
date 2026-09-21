// scripts/events/collect-snapshot.mjs
// Daily snapshot of DeFiLlama /protocols -> data/snapshots/YYYY-MM-DD.json
// Passive: no scoring, no UI. It only accumulates history so that later we can
// show real dynamics ("TVL grew from X to Y in 10 days") and backtest signals.
// Re-running on the same UTC day overwrites that day's file.
//
// Usage:
//   node scripts/events/collect-snapshot.mjs

import fs from "node:fs/promises";
import path from "node:path";
import { ROOT } from "./lib.mjs";

const PROTOCOLS_URL = "https://api.llama.fi/protocols";
const SNAPSHOT_DIR = path.join(ROOT, "data", "snapshots");

const MIN_TVL = 250_000; // keep protocols with at least this TVL ...
const NEW_DAYS = 180; //    ... or listed on DeFiLlama within this many days

function num(v) {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}

function noToken(p) {
  const s = String(p?.symbol ?? "").trim();
  return s === "" || s === "-";
}

async function fetchProtocols() {
  const res = await fetch(PROTOCOLS_URL, {
    headers: { Accept: "application/json", "User-Agent": "Droply-Snapshot/1.0" },
  });
  if (!res.ok) throw new Error(`DeFiLlama /protocols HTTP ${res.status}`);
  const data = await res.json();
  if (!Array.isArray(data)) throw new Error("Unexpected /protocols response");
  return data;
}

function toItem(p) {
  const tvl = num(p.tvl);
  return {
    slug: p.slug || String(p.name || "").toLowerCase().replace(/[^a-z0-9]+/g, "-"),
    name: p.name,
    category: p.category || "",
    chains: Array.isArray(p.chains) ? p.chains.slice(0, 6) : [],
    symbol: p.symbol ?? "",
    tokenless: noToken(p),
    tvl: tvl != null ? Math.round(tvl) : null,
    change1d: num(p.change_1d),
    change7d: num(p.change_7d),
    change1m: num(p.change_1m),
    mcap: num(p.mcap),
    listedAt: num(p.listedAt),
  };
}

function fmtUsd(v) {
  if (v == null) return "n/a";
  if (v >= 1e9) return `$${(v / 1e9).toFixed(2)}B`;
  if (v >= 1e6) return `$${(v / 1e6).toFixed(1)}M`;
  return `$${Math.round(v / 1e3)}K`;
}

async function main() {
  console.log("Snapshot: fetching DeFiLlama /protocols ...");
  const protocols = await fetchProtocols();
  console.log(`Received ${protocols.length} protocols`);

  const dashCount = protocols.filter((p) => String(p?.symbol ?? "").trim() === "-").length;
  const emptyCount = protocols.filter((p) => String(p?.symbol ?? "").trim() === "").length;

  const newCutoffSec = Date.now() / 1000 - NEW_DAYS * 86400;
  const items = protocols
    .filter((p) => p?.name)
    .map(toItem)
    .filter(
      (it) =>
        (it.tvl != null && it.tvl >= MIN_TVL) ||
        (it.listedAt != null && it.listedAt >= newCutoffSec)
    );

  const date = new Date().toISOString().slice(0, 10);
  const snapshot = {
    date,
    fetchedAt: new Date().toISOString(),
    source: "defillama-protocols",
    totalProtocols: protocols.length,
    count: items.length,
    items,
  };

  await fs.mkdir(SNAPSHOT_DIR, { recursive: true });
  const file = path.join(SNAPSHOT_DIR, `${date}.json`);
  await fs.writeFile(file, JSON.stringify(snapshot), "utf8");
  const stat = await fs.stat(file);

  console.log("");
  console.log("=================================");
  console.log("Droply snapshot");
  console.log("=================================");
  console.log(`Date (UTC):          ${date}`);
  console.log(`Protocols total:     ${protocols.length}`);
  console.log(`Kept in snapshot:    ${items.length}`);
  console.log(`  of them tokenless: ${items.filter((i) => i.tokenless).length}`);
  console.log(`symbol == "-":       ${dashCount}`);
  console.log(`symbol empty:        ${emptyCount}`);
  console.log(`File size:           ${(stat.size / 1024).toFixed(0)} KB`);
  console.log(`File:                ${file}`);
  console.log("=================================");

  const growing = items
    .filter((i) => i.tokenless && i.tvl >= 1_000_000 && i.change7d != null)
    .sort((a, b) => b.change7d - a.change7d)
    .slice(0, 10);

  console.log("");
  console.log("Tokenless, TVL >= $1M, top 7d growth:");
  for (const i of growing) {
    console.log(
      `${i.change7d.toFixed(0).padStart(5)}% | ${i.name} | ${i.category} | ${fmtUsd(i.tvl)}`
    );
  }

  const newest = items
    .filter((i) => i.listedAt != null)
    .sort((a, b) => b.listedAt - a.listedAt)
    .slice(0, 10);

  console.log("");
  console.log("Newest listed on DeFiLlama:");
  for (const i of newest) {
    const d = new Date(i.listedAt * 1000).toISOString().slice(0, 10);
    console.log(
      `${d} | ${i.name} | ${i.category} | ${fmtUsd(i.tvl)} | ${i.tokenless ? "no token" : i.symbol}`
    );
  }
  console.log("");
}

main().catch((err) => {
  console.error("Snapshot failed:", err?.message || err);
  process.exitCode = 1;
});
