import type { Metadata } from "next";
import Link from "next/link";
import ProjectCards from "@/components/ProjectCards";
import ChainIcon from "@/components/ChainIcon";
import { getProjects } from "@/lib/projects";
import {
  getChainHubs,
  SEGMENTS,
  describeSegment,
  clip,
  breadcrumbLd,
  itemListLd,
  HUB_MIN,
  SITE_URL,
  type SegmentKey,
} from "@/lib/hubs";

export async function segmentMetadata(key: SegmentKey): Promise<Metadata> {
  const seg = SEGMENTS[key];
  const items = seg.pick(await getProjects());
  const description = clip(describeSegment(key, items));
  const url = SITE_URL + seg.path;
  return {
    title: seg.title,
    description,
    alternates: { canonical: url },
    // A thin page (fewer than HUB_MIN projects) stays out of the index.
    robots: { index: items.length >= HUB_MIN, follow: true },
    openGraph: {
      title: `${seg.title} - Droply`,
      description,
      url,
    },
  };
}

export async function renderSegment(key: SegmentKey) {
  const seg = SEGMENTS[key];
  const projects = await getProjects();
  const items = seg.pick(projects);
  const chains = getChainHubs(projects).slice(0, 12);
  const intro = describeSegment(key, items);
  const others = (Object.keys(SEGMENTS) as SegmentKey[]).filter((k) => k !== key);
  const ld = breadcrumbLd([
    { name: "Home", path: "/" },
    { name: "Airdrops", path: "/airdrops" },
    { name: seg.title, path: seg.path },
  ]);

  return (
    <main className="page container">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ld) }}
      />

      {items.length > 0 ? (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(itemListLd(seg.title, seg.path, items)).replace(/</g, "\\u003c") }}
        />
      ) : null}

      <Link href="/airdrops" className="back-link">&larr; All drops</Link>

      <div className="page-head">
        <div>
          <div className="section-kicker">{seg.kicker}</div>
          <h1>{seg.title}</h1>
          <p>{intro}</p>
        </div>
      </div>

      {items.length > 0 ? (
        <ProjectCards items={items} />
      ) : (
        <p>
          <Link href="/airdrops">Browse all airdrops</Link>
        </p>
      )}

      <section style={{ marginTop: 40 }}>
        <h2>More lists</h2>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
          <Link className="type-pill" href="/airdrops">
            All airdrops
          </Link>
          <Link className="type-pill" href="/airdrops/live">
            Live airdrops
          </Link>
          {others.map((k) => (
            <Link className="type-pill" href={SEGMENTS[k].path} key={k}>
              {SEGMENTS[k].title}
            </Link>
          ))}
        </div>
      </section>

      <section style={{ marginTop: 40 }}>
        <h2>Browse by chain</h2>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
          {chains.map((h) => (
            <Link className="type-pill" href={`/chain/${h.slug}`} key={h.slug}>
              <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}>
                <ChainIcon slug={h.slug} name={h.name} size={16} />
                {h.name} ({h.items.length})
              </span>
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}