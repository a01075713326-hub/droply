import type { Metadata } from "next";
import Link from "next/link";
import AirdropsExplorer from "@/components/AirdropsExplorer";
import { getProjects } from "@/lib/projects";
import { getLiveProjects, SEGMENTS, type SegmentKey } from "@/lib/hubs";

export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  alternates: { canonical: "/airdrops" },
  title: "Airdrops",
  description: "Browse live, upcoming and potential crypto airdrops — filter by chain, status and event type.",
  openGraph: {
    title: "All Airdrops — Droply",
    description: "Browse live, upcoming and potential crypto airdrops — filter by chain, status and event type.",
  },
};

export default async function Airdrops() {
  const projects = await getProjects();
  const lists = [
    { href: "/airdrops/live", label: "Live", n: getLiveProjects(projects).length },
    ...(Object.keys(SEGMENTS) as SegmentKey[]).map((k) => ({
      href: SEGMENTS[k].path,
      label: SEGMENTS[k].title,
      n: SEGMENTS[k].pick(projects).length,
    })),
  ].filter((l) => l.n > 0);

  return (
    <main className="page container">
      <div className="page-head">
        <div>
          <div className="section-kicker">DROP DISCOVERY</div>
          <h1>Crypto Airdrops</h1>
          <p>Upcoming, live and potential drops tracked automatically from multiple sources.</p>
        </div>
      </div>

      {lists.length > 0 ? (
        <nav
          aria-label="Airdrop lists"
          style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 20 }}
        >
          {lists.map((l) => (
            <Link className="type-pill" href={l.href} key={l.href}>
              {l.label} ({l.n})
            </Link>
          ))}
        </nav>
      ) : null}

      <AirdropsExplorer items={projects} />
    </main>
  );
}