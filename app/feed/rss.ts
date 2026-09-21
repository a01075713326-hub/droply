// RSS 2.0 for /feed.xml. Pure functions: rows in, XML string out.
import type { Row } from "./feed-utils";

const SITE = "https://droply.digital";

export function xmlEscape(s: string): string {
  return s
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function itemLink(r: Row): string {
  if (r.internalHref) return SITE + r.internalHref;
  if (r.url && /^https?:\/\//i.test(r.url)) return r.url;
  return SITE + "/feed";
}

function itemTitle(r: Row): string {
  // Project rows already start with the project name; exchange rows need the exchange in front.
  return r.internalHref ? r.title : `${r.exchange}${r.region ? ` ${r.region}` : ""}: ${r.title}`;
}

function itemDescription(r: Row): string {
  if (r.internalHref) return `${r.title}. Details on Droply.`;
  const tickers = r.tickers.map((t) => (t.status !== "announced" ? `${t.ticker} (${t.status})` : t.ticker));
  const parts = [`${r.exchange}${r.region ? ` ${r.region}` : ""} announcement.`];
  if (tickers.length) parts.push(`Tickers: ${tickers.join(", ")}.`);
  if (r.airdrop) parts.push("Airdrop program.");
  return parts.join(" ");
}

/**
 * rows must already be sorted newest first. Rows dated in the future (task deadlines, distribution
 * dates) are left out: an RSS reader expects an item to describe something that already happened.
 */
export function buildRss(rows: Row[], now: Date = new Date(), limit = 50): string {
  const items: { row: Row; date: Date }[] = [];
  for (const row of rows) {
    const date = new Date(row.date);
    if (Number.isNaN(date.getTime()) || date.getTime() > now.getTime()) continue;
    items.push({ row, date });
    if (items.length >= limit) break;
  }

  const lastBuild = items.length ? items[0].date : now;

  const xmlItems = items
    .map(({ row, date }) => {
      const category = [row.type, row.exchange]
        .filter(Boolean)
        .map((c) => `      <category>${xmlEscape(c)}</category>`)
        .join("\n");
      return [
        "    <item>",
        `      <title>${xmlEscape(itemTitle(row))}</title>`,
        `      <link>${xmlEscape(itemLink(row))}</link>`,
        `      <guid isPermaLink="false">${xmlEscape(row.key)}</guid>`,
        `      <pubDate>${date.toUTCString()}</pubDate>`,
        category,
        `      <description>${xmlEscape(itemDescription(row))}</description>`,
        "    </item>",
      ].join("\n");
    })
    .join("\n");

  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">',
    "  <channel>",
    "    <title>Droply Feed</title>",
    `    <link>${SITE}/feed</link>`,
    "    <description>Exchange listings, airdrop programs and updates on the projects Droply tracks.</description>",
    "    <language>en</language>",
    `    <lastBuildDate>${lastBuild.toUTCString()}</lastBuildDate>`,
    `    <atom:link href="${SITE}/feed.xml" rel="self" type="application/rss+xml" />`,
    xmlItems,
    "  </channel>",
    "</rss>",
    "",
  ].join("\n");
}
