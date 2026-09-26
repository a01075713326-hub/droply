import Link from "next/link";
import type { Project } from "@/data/projects";
import { initials } from "@/lib/projects";

function ProjectIcon({ p }: { p: Project }) {
  return p.logo ? (
    <img src={p.logo} alt="" style={{ width: 40, height: 40, borderRadius: "50%", objectFit: "cover", flexShrink: 0 }} />
  ) : (
    <div
      style={{
        width: 40, height: 40, borderRadius: "50%", flexShrink: 0,
        display: "flex", alignItems: "center", justifyContent: "center",
        background: "linear-gradient(135deg,#7c5cff,#4d2eea)", color: "#fff",
        fontWeight: 700, fontSize: 13,
      }}
    >
      {initials(p.name)}
    </div>
  );
}

export function NearestRewardCard({ project }: { project: Project }) {
  return (
    <div className="glass-card nearest-reward">
      <h3>Nearest reward</h3>
      <Link
        href={`/project/${project.slug}`}
        style={{ display: "flex", alignItems: "center", gap: 14, textDecoration: "none", color: "inherit" }}
      >
        <ProjectIcon p={project} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 11, color: "#ff9d6c", marginBottom: 2 }}>
            {project.status === "Live" || project.isLive ? "\u{1F525} Live now" : project.status}
          </div>
          <div style={{ fontWeight: 700 }}>{project.name}</div>
          <div style={{ fontSize: 12, opacity: 0.6 }}>{project.chain}</div>
        </div>
      </Link>
    </div>
  );
}

export function HotActivitiesCard({ projects }: { projects: Project[] }) {
  return (
    <div className="glass-card hot-activities">
      <h3>Hot activities</h3>
      <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
        {projects.map((p) => (
          <Link
            key={p.slug}
            href={`/project/${p.slug}`}
            style={{ display: "flex", alignItems: "center", gap: 12, textDecoration: "none", color: "inherit" }}
          >
            <ProjectIcon p={p} />
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 600, fontSize: 14 }}>{p.name}</div>
              <div style={{ fontSize: 11, opacity: 0.6 }}>{p.chain}</div>
            </div>
            <span className="type-pill" style={{ flexShrink: 0 }}>
              {p.twitterScore ? `\u{1F525} ${p.twitterScore}` : p.status}
            </span>
          </Link>
        ))}
      </div>
    </div>
  );
}
