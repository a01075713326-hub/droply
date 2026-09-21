import type { Metadata } from "next";
import Link from "next/link";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { getProjects } from "@/lib/projects";
import { groupEvents, matchProjects, projectEvents, sortRows, storedProjectKeys } from "./feed-utils";
import type { ProjectInfo, ProjectRef, RawEvent } from "./feed-utils";
import "./feed.css";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Crypto Airdrop News Feed and Exchange Listings",
  alternates: {
    canonical: "https://droply.digital/feed",
    types: { "application/rss+xml": "https://droply.digital/feed.xml" },
  },
  description:
    "Exchange listings, airdrop programs and updates on the projects Droply tracks, newest first.",
};

const TYPE_LABELS: Record<string, string> = {
  listing: "Listing",
  airdrop: "Airdrop",
  project: "Project",
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

async function loadProjectInfos(): Promise<ProjectInfo[]> {
  try {
    const projects = await getProjects();
    return projects.map((p) => ({
      slug: String(p.slug ?? ""),
      name: String(p.name ?? ""),
      event: p.event,
      status: p.status,
      chain: p.chain,
      date: p.date,
      firstSeenAt: (p as unknown as { firstSeenAt?: string }).firstSeenAt,
      distributeDate: p.distributeDate,
      tasks: p.tasks?.map((t) => ({ title: t.title, endDate: t.endDate })),
    }));
  } catch {
    return [];
  }
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

  const [events, projectInfos] = await Promise.all([loadEvents(), loadProjectInfos()]);
  const projectRefs: ProjectRef[] = projectInfos.map(({ slug, name }) => ({ slug, name }));

  const all = sortRows([...groupEvents(events), ...projectEvents(projectInfos, new Date(), storedProjectKeys(events))]);
  const sources = Array.from(new Set(all.map((r) => r.exchange))).sort();
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
          <p>Exchange listings, airdrop programs and updates on the projects Droply tracks, newest first. <a className="feed-link" href="/feed.xml">RSS</a></p>
        </div>
      </div>

      <div className="feed-filters">
        <div className="feed-filter-group">
          <span className="feed-filter-label">Source</span>
          <Link
            href={feedHref({ ...current, exchange: undefined })}
            className={`feed-filter${!exchange ? " feed-filter--active" : ""}`}
          >
            All
          </Link>
          {sources.map((x) => (
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
          {all.length === 0 ? "Nothing here yet." : "No items match these filters."}
        </p>
      ) : (
        <>
          <p className="feed-count">
            {filtered.length > shown.length
              ? `Showing the latest ${shown.length} of ${filtered.length} items`
              : `${filtered.length} item${filtered.length === 1 ? "" : "s"}`}
          </p>
          <ul className="feed-list">
            {shown.map((r) => {
              const projects = r.internalHref ? [] : matchProjects(r, projectRefs);
              return (
                <li className="feed-row" key={r.key}>
                  <div className="feed-when">
                    <span className="feed-date">{formatDate(r.date)}</span>
                    <span className="feed-exchange">
                      {r.exchange}
                      {r.region ? ` ${r.region}` : ""}
                    </span>
                  </div>
                  <div className="feed-main">
                    {(r.tickers.length > 0 || r.airdrop || r.badge) && (
                      <div className="feed-tickers">
                        {r.badge && <span className="feed-badge">{r.badge}</span>}
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
                    {r.internalHref ? (
                      <Link className="feed-title" href={r.internalHref}>
                        {r.title}
                      </Link>
                    ) : r.url && isSafeUrl(r.url) ? (
                      <a
                        className="feed-title"
                        href={r.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        title={r.original !== r.title ? `Original: ${r.original}` : undefined}
                      >
                        {r.title}
                      </a>
                    ) : (
                      <span className="feed-title">{r.title}</span>
                    )}
                    {projects.length > 0 && (
                      <div className="feed-links">
                        <span className="feed-links-label">On Droply</span>
                        {projects.map((p) => (
                          <Link key={p.slug} className="feed-link" href={`/project/${encodeURIComponent(p.slug)}`}>
                            {p.name}
                          </Link>
                        ))}
                      </div>
                    )}
                  </div>
                </li>
              );
            })}
          </ul>
        </>
      )}
    </main>
  );
}
