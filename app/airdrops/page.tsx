import type { Metadata } from "next";
import AirdropsExplorer from "@/components/AirdropsExplorer";
import { getProjects } from "@/lib/projects";

export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  title: "Airdrops",
  description: "Browse live, upcoming and potential crypto airdrops — filter by chain, status and event type.",
  openGraph: {
    title: "All Airdrops — Droply",
    description: "Browse live, upcoming and potential crypto airdrops — filter by chain, status and event type.",
  },
};

export default async function Airdrops() {
  const projects = await getProjects();

  return (
    <main className="page container">
      <div className="page-head">
        <div>
          <div className="section-kicker">DROP DISCOVERY</div>
          <h1>Crypto Airdrops</h1>
          <p>Upcoming, live and potential drops tracked automatically from multiple sources.</p>
        </div>
      </div>

      <AirdropsExplorer items={projects} />
    </main>
  );
}