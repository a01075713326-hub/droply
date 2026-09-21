import type { Metadata } from "next";
import { getProjects } from "@/lib/projects";
import { computeStats } from "@/lib/stats";

export const dynamic = "force-dynamic";
export const metadata: Metadata = {
  alternates: { canonical: "/stats" },
  title: "Crypto Airdrop Stats: New Drops and Active Chains",
  description: "How many new airdrops appeared today and this week, and which chains are most active right now.",
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
    </main>
  );
}
