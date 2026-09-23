"use client";

import { useState, useMemo } from "react";
import Link from "next/link";
import { projects } from "@/data/projects";
import { initials } from "@/lib/projects";
import { ArrowUpRight } from "lucide-react";
import FavoriteButton from "@/components/FavoriteButton";
import MoniGauge from "@/components/MoniGauge";

const STATUSES = ["All", "Potential", "Upcoming", "Live", "Confirmed"] as const;

export default function Calendar() {
  const [status, setStatus] = useState<(typeof STATUSES)[number]>("All");
  const [query, setQuery] = useState("");

    const counts = useMemo(() => {
    const c: Record<string, number> = { All: projects.length };
    for (const s of STATUSES.slice(1)) {
      c[s] = projects.filter((p) => (s === "Live" ? p.status === "Live" || p.isLive === true : p.status === s)).length;
    }
    return c;
  }, []);

  const filtered = useMemo(() => {
    const list = projects.filter((p) => {
            const matchesStatus =
        status === "All" || (status === "Live" ? p.status === "Live" || p.isLive === true : p.status === status);
      const matchesQuery = p.name.toLowerCase().includes(query.toLowerCase());
      return matchesStatus && matchesQuery;
    });

    return [...list].sort((a, b) => {
      const ta = a.firstSeenAt ? new Date(a.firstSeenAt).getTime() : 0;
      const tb = b.firstSeenAt ? new Date(b.firstSeenAt).getTime() : 0;
      return tb - ta;
    });
  }, [status, query]);

  return (
    <main className="page container">
      <div className="page-head">
        <div>
          <div className="section-kicker">DROP CALENDAR</div>
          <h1>All Airdrops</h1>
          <p>Snapshots, TGE dates, claims and airdrop events.</p>
        </div>
      </div>

      <div className="filter-bar">
        <input
          type="text"
          placeholder="Search projects..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
        />
        {STATUSES.map((s) => (
          <button
            key={s}
            onClick={() => setStatus(s)}
            className={status === s ? "active" : ""}
          >
            {s} ({counts[s] ?? 0})
          </button>
        ))}
      </div>

      <div className="event-list">
        {filtered.map((p) => (
            <Link
            key={p.id}
            href={`/project/${p.slug}`}
            className="event-card"
            style={{ display: "flex", alignItems: "center", gap: 20, textDecoration: "none", cursor: "pointer" }}
          >
            <div className="big-project-icon" style={{ flexShrink: 0 }}>
              {p.logo ? <img src={p.logo} alt="" /> : initials(p.name)}
            </div>

            <div style={{ flex: 1, minWidth: 0 }}>
              <h3>{p.name}</h3>
              <div className="req-pills" style={{ marginTop: 6 }}>
                <span className="type-pill">{p.chain}</span>
                <span className="type-pill">{p.event}</span>
                {p.requirements && p.requirements[0] && (
                  <span className="type-pill">{p.requirements[0]}</span>
                )}
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", gap: 12, flexShrink: 0, marginLeft: "auto" }}>
              <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <span className={`status-pill ${p.status.toLowerCase()}`}>{p.status}</span>
              {p.isLive && (
                <span style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 11, color: "#5be0b5" }}>
                  <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#5be0b5", display: "inline-block" }} />
                  Live now
                </span>
              )}
            </span>
              <span className="crx-gauge-slot">{p.twitterScore != null ? <MoniGauge score={Number(p.twitterScore)} compact /> : null}</span>
              <span onClick={(e) => e.stopPropagation()}><FavoriteButton slug={p.slug} /></span>
              <ArrowUpRight size={18} style={{ color: "#647083" }} />
            </div>
          </Link>
        ))}

        {filtered.length === 0 && (
          <p className="muted" style={{ padding: "20px 0" }}>No projects match your filters.</p>
        )}
      </div>
    </main>
  );
}