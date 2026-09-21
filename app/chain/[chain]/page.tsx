import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import ProjectCards from "@/components/ProjectCards";
import ChainIcon from "@/components/ChainIcon";
import { getProjects } from "@/lib/projects";
import {
  getChainHubs,
  describeHub,
  clip,
  breadcrumbLd,
  itemListLd,
  SITE_URL,
} from "@/lib/hubs";

export const dynamic = "force-dynamic";

type Props = { params: Promise<{ chain: string }> };

async function load(slug: string) {
  const projects = await getProjects();
  const hubs = getChainHubs(projects);
  const hub = hubs.find((h) => h.slug === slug);
  return { hub, hubs };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { chain } = await params;
  const { hub } = await load(chain);
  if (!hub) {
    return { title: "Not found", robots: { index: false, follow: false } };
  }
  const description = clip(describeHub("chain", hub.name, hub.items));
  const url = `${SITE_URL}/chain/${hub.slug}`;
  return {
    title: `${hub.name} Airdrops`,
    description,
    alternates: { canonical: url },
    openGraph: {
      title: `${hub.name} Airdrops - Droply`,
      description,
      url,
    },
  };
}

export default async function ChainHub({ params }: Props) {
  const { chain } = await params;
  const { hub, hubs } = await load(chain);
  if (!hub) notFound();

  const intro = describeHub("chain", hub.name, hub.items);
  const others = hubs.filter((h) => h.slug !== hub.slug).slice(0, 12);
  const ld = breadcrumbLd([
    { name: "Home", path: "/" },
    { name: "Airdrops", path: "/airdrops" },
    { name: `${hub.name} Airdrops`, path: `/chain/${hub.slug}` },
  ]);

  return (
    <main className="page container">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ld) }}
      />

      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(itemListLd(`${hub.name} Airdrops`, `/chain/${hub.slug}`, hub.items)).replace(/</g, "\\u003c") }}
      />

      <Link href="/airdrops" className="back-link">&larr; All drops</Link>

      <div className="page-head">
        <div>
          <div className="section-kicker">CHAIN</div>
          <h1 style={{ display: "flex", alignItems: "center", gap: 12 }}><ChainIcon slug={hub.slug} name={hub.name} size={36} />{hub.name} Airdrops</h1>
          <p>{intro}</p>
        </div>
      </div>

      <ProjectCards items={hub.items} />

      <section style={{ marginTop: 40 }}>
        <h2>More airdrops</h2>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
          <Link className="type-pill" href="/airdrops">
            All airdrops
          </Link>
          <Link className="type-pill" href="/airdrops/live">
            Live airdrops
          </Link>
          {others.map((h) => (
            <Link className="type-pill" href={`/chain/${h.slug}`} key={h.slug}>
              <span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}><ChainIcon slug={h.slug} name={h.name} size={16} />{h.name} ({h.items.length})</span>
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}