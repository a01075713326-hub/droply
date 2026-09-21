"use client";

import Link from "next/link";
import { Project } from "@/data/projects";
import { initials, cardActions, truncate } from "@/lib/projects";
import FavoriteButton from "@/components/FavoriteButton";
import DeadlineBadge from "@/components/DeadlineBadge";

export default function ProjectCards({ items }: { items: Project[] }) {
  return (
    <div className="project-grid">
      {items.map((p) => {
        const body = cardActions(p.actions) || truncate(p.description, 90);
        return (
          <Link className="project-card" href={`/project/${p.slug}`} key={p.id}>
            <FavoriteButton slug={p.slug} />
            <div className="card-badges">
              <span className={`status-pill ${p.status.toLowerCase()}`}>{p.status}</span>
              {p.event.split(",").map((e) => <span className="type-pill" key={e}>{e.trim()}</span>)}
              <DeadlineBadge deadline={p.deadline} date={p.date} />
            </div>
            <div className="card-top">
              <div className="project-icon card-icon">
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
              </div>
              <div>
                <strong className="card-name">{p.name}</strong>
                <small className="card-chain">{p.chain}</small>
              </div>
            </div>
            <p className="card-body">{body}</p>
            <div className="card-footer">
              <span className="card-reward">{p.symbol ? "$" + p.symbol : "Reward TBA"}</span>
              <span className="card-open">Open project &rarr;</span>
            </div>
          </Link>
        );
      })}
    </div>
  );
}

