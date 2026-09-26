"use client";

import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { Project } from "@/data/projects";
import { formatDate, initials, truncate } from "@/lib/project-utils";
import FavoriteButton from "@/components/FavoriteButton";
import DeadlineBadge from "@/components/DeadlineBadge";

export default function ProjectTable({ items }: { items: Project[] }) {
  return (
    <div className="table-card">
      <div className="table-head"><span>Project</span><span>Blockchain</span><span>Type</span><span>Reward</span><span>Date</span><span>Status</span><span></span></div>
      {items.map((p) => (
        <Link className="project-row" href={`/project/${p.slug}`} key={p.id}>
          <div className="project-cell"><div className="project-icon">
              {p.logo ? (
                <img
                  src={p.logo}
                  alt={p.name}
                  loading="lazy"
                  onError={(e) => {
                    e.currentTarget.style.display = "none";
                    e.currentTarget.nextElementSibling?.classList.remove("hidden");
                  }}
                />
              ) : null}
              <span className={p.logo ? "hidden" : ""}>{initials(p.name)}</span>
            </div><div><strong>{p.name}</strong><small>{truncate(p.description, 40)}</small></div></div>
          <div className="muted">{p.chain}</div>
          <div><span className="type-pill">{p.event}</span></div>
          <div className="muted">{p.symbol ? "$" + p.symbol : "TBA"}</div>
          <div className="muted">{formatDate(p.date)}<DeadlineBadge deadline={p.deadline} date={p.date} /></div>
          <div><span className={`status-pill ${p.status.toLowerCase()}`}>{p.status}</span></div>
          <ChevronRight className="row-arrow" size={17}/>
        </Link>
      ))}
    </div>
  );
}


