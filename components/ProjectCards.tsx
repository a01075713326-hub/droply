"use client";

import Link from "next/link";
import { Project } from "@/data/projects";
import { initials, cardActions, truncate } from "@/lib/projects";
import FavoriteButton from "@/components/FavoriteButton";
import DeadlineBadge from "@/components/DeadlineBadge";
import ChainIcon from "@/components/ChainIcon";
import MoniGauge from "@/components/MoniGauge";

type CryptoRankFields = {
  timeToFarm?: string;
  activityPoints?: number;
};

export default function ProjectCards({ items }: { items: Project[] }) {
  return (
    <div className="project-grid">
      {items.map((p) => {
        const body =
          cardActions(p.actions) || truncate(p.description, 90);

        /*
         * CryptoRank-specific fields.
         */
        const cr = p as Project & CryptoRankFields;

        const isCryptoRank =
          p.source === "CryptoRank" ||
          p.sourceUrl?.includes("cryptorank.io") ||
          cr.timeToFarm != null ||
          cr.activityPoints != null;

        return (
          <Link
            className={`project-card ${
              isCryptoRank ? "cryptorank-card" : ""
            }`}
            href={`/project/${p.slug}`}
            key={p.id}
          >
            <FavoriteButton slug={p.slug} />

            <div className="card-badges">
              <span className={`status-pill ${p.status.toLowerCase()}`}>
                {p.status}
              </span>

              {p.event
                .split(",")
                .map((e) => (
                  <span className="type-pill" key={e}>
                    {e.trim()}
                  </span>
                ))}

              <DeadlineBadge
                deadline={p.deadline}
                date={p.date}
              />
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
                      e.currentTarget.nextElementSibling?.classList.remove(
                        "hidden"
                      );
                    }}
                  />
                ) : null}

                <span className={p.logo ? "hidden" : ""}>
                  {initials(p.name)}
                </span>
              </div>

              <div>
                <strong className="card-name">
                  {p.name}
                </strong>

                <small className="card-chain"><ChainIcon chain={p.chain} size={14} inline />
                  {p.chain}
                </small>
              </div>
            </div>

            <p className="card-body">
              {body}
            </p>

            {isCryptoRank ? (
              <div className="card-meta cryptorank-meta">
                {p.costToFarm ? (
                  <span>
                    <b>Cost:</b> {p.costToFarm}
                  </span>
                ) : null}

                {cr.timeToFarm ? (
                  <span>
                    <b>Time:</b> {cr.timeToFarm}
                  </span>
                ) : null}

                {cr.activityPoints != null ? (
                  <span>
                    <b>Points:</b> {cr.activityPoints}
                  </span>
                ) : null}
              </div>
            ) : null}

            <div className="card-footer">
              <span className="card-reward">
                {p.symbol ? "$" + p.symbol : "Reward TBA"}
              </span>

              {p.twitterScore != null ? <MoniGauge score={Number(p.twitterScore)} compact /> : null}

              <span className="card-open">
                Open project &rarr;
              </span>
            </div>
          </Link>
        );
      })}
    </div>
  );
}

