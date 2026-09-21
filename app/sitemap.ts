import type { MetadataRoute } from "next";
import { getProjects } from "@/lib/projects";
import { getVerification } from "@/lib/verification";
import { getOverride, isIndexable } from "@/lib/overrides";
import { getChainHubs, getCategoryHubs, getLiveProjects, SEGMENTS, HUB_MIN, type SegmentKey } from "@/lib/hubs";

const BASE = "https://droply.digital";

function toDate(value?: string): Date | null {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

// Latest real event we know about for a project: first seen by sync,
// our own review, or the verification check. Future dates are ignored.
function lastModifiedFor(p: any): Date | undefined {
  const now = Date.now();
  const dates = [
    toDate(p.firstSeenAt),
    toDate(getOverride(p.slug)?.updatedAt),
    toDate(getVerification(p.slug)?.checkedAt),
  ].filter((d): d is Date => d !== null && d.getTime() <= now);

  if (!dates.length) return undefined;
  return new Date(Math.max(...dates.map((d) => d.getTime())));
}

function latestFor(items: any[]): Date | undefined {
  const times = items
    .map((p) => lastModifiedFor(p))
    .filter((d): d is Date => d !== undefined)
    .map((d) => d.getTime());
  return times.length ? new Date(Math.max(...times)) : undefined;
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const projects = await getProjects();

  const projectRoutes: MetadataRoute.Sitemap = projects.filter((p) => isIndexable(p)).map((p) => ({
    url: `${BASE}/project/${p.slug}`,
    lastModified: lastModifiedFor(p),
  }));

  const stamps = projectRoutes
    .map((r) => (r.lastModified ? new Date(r.lastModified).getTime() : 0))
    .filter((t) => t > 0);
  const listModified = stamps.length ? new Date(Math.max(...stamps)) : undefined;

  // Only indexable canonical pages. /calendar and /favorites are noindex, so they are left out.
  const staticRoutes: MetadataRoute.Sitemap = ["", "/airdrops"].map((route) => ({
    url: `${BASE}${route}`,
    lastModified: listModified,
  }));

  const legalRoutes: MetadataRoute.Sitemap = ["/about", "/contact", "/disclaimer", "/privacy"].map((route) => ({
    url: `${BASE}${route}`,
    lastModified: new Date("2026-09-20"),
  }));

  const chainHubs = getChainHubs(projects);
  const categoryHubs = getCategoryHubs(projects);
  const liveProjects = getLiveProjects(projects);

  // Hub pages: only those with enough projects (same rule as the pages themselves).
  const hubRoutes: MetadataRoute.Sitemap = [
    ...chainHubs.map((h) => ({
      url: `${BASE}/chain/${h.slug}`,
      lastModified: latestFor(h.items),
    })),
    ...categoryHubs.map((h) => ({
      url: `${BASE}/category/${h.slug}`,
      lastModified: latestFor(h.items),
    })),
    ...(liveProjects.length >= HUB_MIN
      ? [{ url: `${BASE}/airdrops/live`, lastModified: latestFor(liveProjects) }]
      : []),
  ];

  // Segment lists (confirmed / points / no-token): same HUB_MIN rule as the pages.
  const segmentRoutes: MetadataRoute.Sitemap = (Object.keys(SEGMENTS) as SegmentKey[]).flatMap((k) => {
    const items = SEGMENTS[k].pick(projects);
    return items.length >= HUB_MIN
      ? [{ url: `${BASE}${SEGMENTS[k].path}`, lastModified: latestFor(items) }]
      : [];
  });

  // The feed and stats have no lastModified on purpose: they change with every collector run.
  const feedRoutes: MetadataRoute.Sitemap = [{ url: `${BASE}/feed` }, { url: `${BASE}/stats` }];

  return [...staticRoutes, ...feedRoutes, ...hubRoutes, ...segmentRoutes, ...legalRoutes, ...projectRoutes];
}