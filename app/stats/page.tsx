import type { Metadata } from "next";
import { getProjects } from "@/lib/projects";
import { computeStats } from "@/lib/stats";

export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  alternates: { canonical: "/stats" },
  title: "Crypto Airdrop Stats: New Drops and Active Chains",
  description: "How many new crypto airdrops appeared today and this week, and which blockchains are most active right now. Based on the projects Droply tracks.",
};

export default async function StatsPage() {
  const projects = await getProjects();
  const stats = computeStats(projects);
  const maxChainCount = stats.byChain[0]?.count || 1;

  return (
    <main className="page container">
      <div className="page-head">
        <div>
          <div className="section-kicker">OVERVIEW</div>
          <h1>Airdrop Stats</h1>
          <p>A quick look at how many drops are tracked and where the activity is right now.</p>
        </div>
      </div>

      <div className="stats-summary">
        <div className="stat-card">
          <div className="stat-value">{stats.total}</div>
          <div className="stat-label">Total drops tracked</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{stats.newToday}</div>
          <div className="stat-label">New in last 24h</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{stats.newThisWeek}</div>
          <div className="stat-label">New in last 7 days</div>
        </div>
      </div>

      <h2 className="stats-subheading">Most active chains</h2>
      <div className="chain-bars">
        {stats.byChain.map((c) => (
          <div className="chain-bar-row" key={c.chain}>
            <span className="chain-bar-label">{c.chain}</span>
            <div className="chain-bar-track">
              <div
                className="chain-bar-fill"
                style={{ width: `${Math.max(4, (c.count / maxChainCount) * 100)}%` }}
              />
            </div>
            <span className="chain-bar-count">{c.count}</span>
          </div>
        ))}
      </div>

      <h2 className="stats-subheading">By status</h2>
      <div className="status-pills">
        {stats.byStatus.map((s) => (
          <span className="status-pill" key={s.status}>
            {s.status}: {s.count}
          </span>
        ))}
      </div>
      <p className="stats-note">These figures are calculated each time the page loads, from the projects currently in the Droply tracker, so they always match the project pages. Project data comes from CryptoRank and is supplemented with manually checked details for selected projects. A drop counts as new when it was first added to the Droply tracker within the last 24 hours or 7 days. The chart shows the ten most active chains, and a project on several chains is counted for each of them.</p>
    </main>
  );
}
