import { notFound } from "next/navigation";
import { getProjects, getProject, initials } from "@/lib/projects";
import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import GuideSteps from "@/components/GuideSteps";
import FavoriteButton from "@/components/FavoriteButton";
import DeadlineBadge from "@/components/DeadlineBadge";

export async function generateStaticParams() {
  const projects = await getProjects();
  return projects.map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const p = await getProject((await params).slug);
  if (!p) return { title: "Project" };

  const title = `${p.name} Airdrop \u2014 Guide, Steps & Rewards`;
  const description = p.description;
  const url = `https://droply.digital/project/${p.slug}`;

  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: {
      title,
      description,
      url,
      type: "article",
      images: p.logo ? [{ url: p.logo }] : undefined,
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      images: p.logo ? [p.logo] : undefined,
    },
  };
}

export default async function ProjectPage({ params }: { params: Promise<{ slug: string }> }) {
  const p = await getProject((await params).slug);
  if (!p) notFound();

  const jsonLd = p.actions && p.actions.length ? {
    "@context": "https://schema.org",
    "@type": "HowTo",
    "name": `How to participate in the ${p.name} airdrop`,
    "description": p.description,
    "step": p.actions.map((action, i) => ({
      "@type": "HowToStep",
      "position": i + 1,
      "text": action,
    })),
  } : null;

  const hasLinks = p.x || p.telegram || p.discord || p.whitepaper || p.docs;

  return (
    <main className="page container project-page">
      {jsonLd && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      )}
      <Link href="/airdrops" className="back-link">&larr; All drops</Link>

      <div className="project-hero">
        <div className="big-project-icon">
          {p.logo ? <img src={p.logo} alt="" /> : initials(p.name)}
        </div>
        <div>
          <div className="section-kicker">{p.chain.toUpperCase()}</div>
          <h1>{p.name}{p.symbol ? <span className="ticker-tag">${p.symbol}</span> : null}</h1>
          <p>{p.description}</p>
          {p.requirements && p.requirements.length ? (
            <div className="req-pills">
              {p.requirements.map((r) => <span key={r} className="type-pill">{r}</span>)}
            </div>
          ) : null}
        </div>
         <span style={{ display: "flex", alignItems: "center", gap: 8 }}>
          <span className={`status-pill ${p.status.toLowerCase()}`}>{p.status}</span>
          {p.isLive && (
            <span style={{ display: "flex", alignItems: "center", gap: 4, fontSize: 12, color: "#5be0b5" }}>
              <span style={{ width: 6, height: 6, borderRadius: "50%", background: "#5be0b5", display: "inline-block" }} />
              Live now
            </span>
          )}
        </span>
      </div>

      <div className="metrics-grid">
        <div><span>EVENT</span><b>{p.event}</b></div>
        <div><span>DIFFICULTY</span><b>{p.difficulty || "\u2014"}</b></div>
        <div><span>COST TO FARM</span><b>{p.costToFarm || "\u2014"}</b></div>
        <div><span>BLOCKCHAIN</span><b>{p.chain}</b></div>
      </div>

      <section className="article-card">
        <div className="section-kicker">DROP DETAILS</div>
        <h2>About {p.name}</h2>
        <p>{p.description}</p>
        <div className="source-actions">
          {p.claimUrl && <a href={p.claimUrl} target="_blank" rel="noreferrer" className="primary-btn">View Airdrop <ArrowUpRight size={15}/></a>}
          {p.website && <a href={p.website} target="_blank" rel="noreferrer" className="glass-btn">Official Website <ArrowUpRight size={15}/></a>}
          <Link href="/calendar" className="glass-btn">View calendar</Link>
        </div>
        {p.source && <small className="muted">Source: {p.source}</small>}
      </section>

      {p.actions && p.actions.length ? (
        <section className="article-card">
          <div className="section-kicker">HOW TO PARTICIPATE</div>
          <h2>Step-by-step guide</h2>
          <GuideSteps actions={p.actions} slug={p.slug} />
        </section>
      ) : null}

      {hasLinks ? (
        <section className="article-card">
          <div className="section-kicker">LINKS</div>
          <div className="source-actions">
            {p.x && <a href={p.x} target="_blank" rel="noreferrer" className="glass-btn">X / Twitter <ArrowUpRight size={15}/></a>}
            {p.telegram && <a href={p.telegram} target="_blank" rel="noreferrer" className="glass-btn">Telegram <ArrowUpRight size={15}/></a>}
            {p.discord && <a href={p.discord} target="_blank" rel="noreferrer" className="glass-btn">Discord <ArrowUpRight size={15}/></a>}
            {p.whitepaper && <a href={p.whitepaper} target="_blank" rel="noreferrer" className="glass-btn">Whitepaper <ArrowUpRight size={15}/></a>}
            {p.docs && <a href={p.docs} target="_blank" rel="noreferrer" className="glass-btn">Docs <ArrowUpRight size={15}/></a>}
          </div>
        </section>
      ) : null}
    </main>
  );
}

