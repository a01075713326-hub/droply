import type { Metadata } from "next";
import Link from "next/link";
import { readFile } from "node:fs/promises";
import path from "node:path";
import "./feed.css";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Feed",
  description:
    "Exchange listing announcements and airdrop-related posts from major exchanges, in one place.",
};

type RawEvent = {
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
  };
  firstSeenAt?: string;
};

type Row = {
  key: string;
  date: string;
  type: string;
  exchange: string;
  region: string;
  title: string;
  url: string;
  airdrop: boolean;
  tickers: { ticker: string; status: string }[];
};

const TYPE_LABELS: Record<string, string> = {
  listing: "Listing",
};

const MAX_ROWS = 300;

async function loadEvents(): Promise<RawEvent[]> {
  try {
    const raw = await readFile(path.join(process.cwd(), "data", "events.json"), "utf8");
    const parsed = JSON.parse(raw.replace(/^\uFEFF/, ""));
    if (Array.isArray(parsed)) return parsed;
    if (parsed && Array.isArray(parsed.events)) return parsed.events;
    return [];
  } catch {
    return [];
  }
}

// One announcement can produce several events (one per ticker) with the same URL.
// Show it as a single row with a chip per ticker.
function groupEvents(events: RawEvent[]): Row[] {
  const rows = new Map<string, Row>();
  for (const e of events) {
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
    rows.set(key, {
      key,
      date: e.date || "",
      type: e.type || "other",
      exchange: e.data?.exchange || "Other",
      region: e.data?.region && e.data.region !== "global" ? e.data.region : "",
      title: e.data?.originalTitle || e.title || "",
      url: e.url || "",
      airdrop: Boolean(e.data?.airdropRelated),
      tickers: ticker ? [{ ticker, status }] : [],
    });
  }
  return Array.from(rows.values()).sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
}

function formatDate(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "" : d.toISOString().slice(0, 10);
}

function typeLabel(type: string): string {
  return TYPE_LABELS[type] || type.charAt(0).toUpperCase() + type.slice(1);
}

function isSafeUrl(url: string): boolean {
  return /^https?:\/\//i.test(url);
}

function feedHref(params: Record<string, string | undefined>): string {
  const q = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (v) q.set(k, v);
  }
  const s = q.toString();
  return s ? `/feed?${s}` : "/feed";
}

function first(v: string | string[] | undefined): string | undefined {
  return Array.isArray(v) ? v[0] : v;
}

export default async function FeedPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const sp = await searchParams;
  const exchange = first(sp.exchange);
  const type = first(sp.type);
  const airdropOnly = first(sp.airdrop) === "1";

  const all = groupEvents(await loadEvents());
  const exchanges = Array.from(new Set(all.map((r) => r.exchange))).sort();
  const types = Array.from(new Set(all.map((r) => r.type))).sort();

  const filtered = all.filter(
    (r) =>
      (!exchange || r.exchange === exchange) &&
      (!type || r.type === type) &&
      (!airdropOnly || r.airdrop)
  );
  const shown = filtered.slice(0, MAX_ROWS);

  const current = { exchange, type, airdrop: airdropOnly ? "1" : undefined };

  return (
    <main className="page container">
      <div className="page-head">
        <div>
          <div className="section-kicker">EVENTS</div>
          <h1>Feed</h1>
          <p>Exchange listing announcements and airdrop-related posts from major exchanges, newest first.</p>
        </div>
      </div>

      <div className="feed-filters">
        <div className="feed-filter-group">
          <span className="feed-filter-label">Exchange</span>
          <Link
            href={feedHref({ ...current, exchange: undefined })}
            className={`feed-filter${!exchange ? " feed-filter--active" : ""}`}
          >
            All
          </Link>
          {exchanges.map((x) => (
            <Link
              key={x}
              href={feedHref({ ...current, exchange: x })}
              className={`feed-filter${exchange === x ? " feed-filter--active" : ""}`}
            >
              {x}
            </Link>
          ))}
        </div>

        {types.length > 1 && (
          <div className="feed-filter-group">
            <span className="feed-filter-label">Type</span>
            <Link
              href={feedHref({ ...current, type: undefined })}
              className={`feed-filter${!type ? " feed-filter--active" : ""}`}
            >
              All
            </Link>
            {types.map((t) => (
              <Link
                key={t}
                href={feedHref({ ...current, type: t })}
                className={`feed-filter${type === t ? " feed-filter--active" : ""}`}
              >
                {typeLabel(t)}
              </Link>
            ))}
          </div>
        )}

        <div className="feed-filter-group">
          <Link
            href={feedHref({ ...current, airdrop: airdropOnly ? undefined : "1" })}
            className={`feed-filter${airdropOnly ? " feed-filter--active" : ""}`}
          >
            Airdrop programs only
          </Link>
        </div>
      </div>

      {shown.length === 0 ? (
        <p className="feed-empty">
          {all.length === 0 ? "No events collected yet." : "No events match these filters."}
        </p>
      ) : (
        <>
          <p className="feed-count">
            {filtered.length > shown.length
              ? `Showing the latest ${shown.length} of ${filtered.length} announcements`
              : `${filtered.length} announcement${filtered.length === 1 ? "" : "s"}`}
          </p>
          <ul className="feed-list">
            {shown.map((r) => (
              <li className="feed-row" key={r.key}>
                <div className="feed-when">
                  <span className="feed-date">{formatDate(r.date)}</span>
                  <span className="feed-exchange">
                    {r.exchange}
                    {r.region ? ` ${r.region}` : ""}
                  </span>
                </div>
                <div className="feed-main">
                  {(r.tickers.length > 0 || r.airdrop) && (
                    <div className="feed-tickers">
                      {r.airdrop && <span className="feed-badge">Airdrop</span>}
                      {r.tickers.map((t) => (
                        <span
                          key={t.ticker}
                          className={`feed-chip${t.status === "cancelled" ? " feed-chip--cancelled" : ""}`}
                        >
                          {t.ticker}
                          {t.status !== "announced" ? ` (${t.status})` : ""}
                        </span>
                      ))}
                    </div>
                  )}
                  {r.url && isSafeUrl(r.url) ? (
                    <a className="feed-title" href={r.url} target="_blank" rel="noopener noreferrer">
                      {r.title}
                    </a>
                  ) : (
                    <span className="feed-title">{r.title}</span>
                  )}
                </div>
              </li>
            ))}
          </ul>
        </>
      )}
    </main>
  );
}
