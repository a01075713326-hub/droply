import "./cryptorank-overview-v2.css";
import "./badge-caution.css";
import "./hero-redesign.css";
import "./verify-faq-tone.css";
import { notFound } from "next/navigation";
import "./hero-status.css";
import { getProjects, getProject, initials } from "@/lib/projects";
import { getVerification } from "@/lib/verification";
import { getOverride, isIndexable } from "@/lib/overrides";
import Link from "next/link";
import { ArrowUpRight, Rocket } from "lucide-react";
import GuideSteps from "@/components/GuideSteps";
import FavoriteButton from "@/components/FavoriteButton";
import DeadlineBadge from "@/components/DeadlineBadge";
import VerificationBlock from "@/components/VerificationBlock";
import ProjectBadges, { type BadgeState } from "@/components/ProjectBadges";
import LinksPanel, { type PanelLink } from "@/components/LinksPanel";
import CryptoRankDetails from "@/components/CryptoRankDetails";
import CryptoRankTasks from "@/components/CryptoRankTasks";
import ChainIcon from "@/components/ChainIcon";
import ProjectLogo from "@/components/ProjectLogo";
import { getProjectTimeline } from "@/lib/events";

export async function generateStaticParams() {
  const projects = await getProjects();
  return projects.map((p) => ({ slug: p.slug }));
}

const GENERIC_CHAINS = new Set(["other", "multiple", "testnet", ""]);

// Similar projects: same chain or same category, so every project page links
// to a few others and is not an orphan. A match on status alone is not enough.
function getRelated(p: any, all: any[], limit = 4): any[] {
  const chain = String(p.chain || "").toLowerCase();
  const category = String(p.category || "").toLowerCase();
  const eco = new Set((p.ecosystems || []).map((e: any) => String(e).toLowerCase()));

  return all
    .filter((o: any) => o.slug !== p.slug)
    .map((o: any) => {
      let score = 0;
      const oc = String(o.chain || "").toLowerCase();
      if (chain && !GENERIC_CHAINS.has(chain) && oc === chain) score += 3;
      if (category && String(o.category || "").toLowerCase() === category) score += 2;
      const overlap = (o.ecosystems || []).filter((e: any) => eco.has(String(e).toLowerCase())).length;
      score += Math.min(overlap, 2);
      if (o.status === p.status) score += 0.5;
      return { o, score };
    })
    .filter((x: any) => x.score >= 2)
    .sort((a: any, b: any) => b.score - a.score)
    .slice(0, limit)
    .map((x: any) => x.o);
}

type FaqItem = { q: string; a: string };

function fmtLongDate(value?: string): string {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  });
}

// Meta description assembled from the project's own facts.
function buildDescription(p: any): string {
  const facts: string[] = [];
  if (p.status) facts.push("Status: " + p.status);
  if (p.chain) facts.push("Chain: " + p.chain);
  if (p.costToFarm) facts.push("Cost to farm: " + p.costToFarm);
  if (p.timeToFarm) facts.push("Time: " + p.timeToFarm);

  const head = p.name + " airdrop guide \u2014 how to participate, tasks and requirements.";
  const text = facts.length ? head + " " + facts.join(" \u00b7 ") : head;
  return text.length > 158 ? text.slice(0, 155).trimEnd() + "\u2026" : text;
}

// FAQ answers use only data the project really has; a question with no data is skipped.
function buildFaq(p: any): FaqItem[] {
  const out: FaqItem[] = [];
  const name = String(p.name);
  const tasks = Array.isArray(p.tasks) ? p.tasks : [];

  if (p.status) {
    let a = name + " is currently listed as " + p.status + ".";
    if (p.isLive) a += " The campaign is live right now.";
    out.push({ q: "Is the " + name + " airdrop confirmed?", a });
  }

  const dist = fmtLongDate(p.distributeDate);
  const ends = tasks.map((t: any) => t?.endDate).filter(Boolean).sort();
  const lastEnd = fmtLongDate(ends[ends.length - 1]);

  if (dist) {
    out.push({
      q: "When is the " + name + " airdrop distribution?",
      a: "Distribution is listed for " + dist + ".",
    });
  } else if (lastEnd) {
    out.push({
      q: "When is the deadline for the " + name + " airdrop?",
      a: "The latest task deadline listed is " + lastEnd + ". No distribution date is listed yet.",
    });
  }

  const cost = p.costToFarm ? String(p.costToFarm) : "";
  const time = p.timeToFarm ? String(p.timeToFarm) : "";
  if (cost || time) {
    const parts: string[] = [];
    if (cost) parts.push("Estimated cost to farm: " + cost + ".");
    if (time) parts.push("Estimated time: " + time + ".");
    out.push({ q: "How much does it cost to farm the " + name + " airdrop?", a: parts.join(" ") });
  }

  if (p.chain) {
    out.push({
      q: "Which blockchain does " + name + " use?",
      a: name + " is listed on " + p.chain + ".",
    });
  }

  if (p.lifeCycle === "funding" || p.lifeCycle === "scheduled") {
    out.push({
      q: "Has " + name + " launched a token yet?",
      a:
        name +
        " is listed on CryptoRank at the " +
        p.lifeCycle +
        " stage, which usually comes before a token launch. Status can change, so check the official channels.",
    });
  }

  const steps = Array.isArray(p.actions) && p.actions.length ? p.actions.length : tasks.length;
  if (steps) {
    out.push({
      q: "How do I participate in the " + name + " airdrop?",
      a: "The guide above lists " + steps + (steps === 1 ? " step" : " steps") + " to follow.",
    });
  }

  return out;
}
export async function generateMetadata({ params }: { params: Promise<{ slug: string }> }) {
  const p = await getProject((await params).slug);
  if (!p) return { title: "Project" };

  const title = `${p.name} Airdrop \u2014 Guide, Steps & Rewards`;
  const ov = getOverride(p.slug);
  const description = ov?.summary
    ? ov.summary.length > 158
      ? ov.summary.slice(0, 155).trimEnd() + "\u2026"
      : ov.summary
    : buildDescription(p);
  const url = `https://droply.digital/project/${p.slug}`;

  return {
    title,
    description,
    alternates: { canonical: url },
    robots: isIndexable(p) ? { index: true, follow: true } : { index: false, follow: true },
    openGraph: {
      title,
      description,
      url,
      type: "article",
      
    },
    twitter: {
      card: "summary_large_image",
      title,
      description,
      
    },
  };
}

export default async function ProjectPage({ params }: { params: Promise<{ slug: string }> }) {
  const p = await getProject((await params).slug);
  if (!p) notFound();

  const verification = getVerification(p.slug);
  const isCryptoRank = String(p.source || "").toLowerCase().includes("cryptorank");

  // TODO: replace with real ProjectVerification fields once confirmed --
  // this assumes an `audits` / `contracts` array with a `status` field.
  const v = verification as any;
  const auditState: BadgeState = !v
    ? "unknown"
    : v.audits?.some((a: any) => a.status === "confirmed")
      ? "ok"
      : v.audits?.length
        ? "warn"
        : "unknown";
  const contractState: BadgeState = !v
    ? "unknown"
    : v.contracts?.some((c: any) => c.status === "confirmed")
      ? "ok"
      : v.contracts?.length
        ? "warn"
        : "unknown";

  const official: PanelLink[] = [
    p.website && { kind: "website", title: "Official Website", url: p.website },
    p.claimUrl && { kind: "claim", title: "Airdrop / Claim Page", url: p.claimUrl },
    p.docs && { kind: "docs", title: "Docs / Guide", url: p.docs },
    p.whitepaper && { kind: "whitepaper", title: "Whitepaper", url: p.whitepaper },
  ].filter(Boolean) as PanelLink[];

  const social: PanelLink[] = [
    p.x && { kind: "x", title: "X (Twitter)", url: p.x },
    p.telegram && { kind: "telegram", title: "Telegram", url: p.telegram },
    p.discord && { kind: "discord", title: "Discord", url: p.discord },
  ].filter(Boolean) as PanelLink[];

  const ov = getOverride(p.slug);
  const steps: string[] = ov?.steps?.length ? ov.steps : (p.actions ?? []);
  const timeline = await getProjectTimeline(p.slug, p.firstSeenAt);
  const allProjects = await getProjects();
  const related = getRelated(p, allProjects);
  const metaLine = [
    p.firstSeenAt ? "Tracked on Droply since " + fmtLongDate(p.firstSeenAt) : "",
    ov?.updatedAt ? "Reviewed " + fmtLongDate(ov.updatedAt) : "",
  ]
    .filter(Boolean)
    .join(" \u00b7 ");
  const faqItems = buildFaq({ ...p, actions: steps });

  const jsonLd = steps.length ? {
    "@context": "https://schema.org",
    "@type": "HowTo",
    ...(p.firstSeenAt ? { datePublished: new Date(p.firstSeenAt).toISOString() } : {}),
    "name": `How to participate in the ${p.name} airdrop`,
    "description": p.description,
    "step": steps.map((action, i) => ({
      "@type": "HowToStep",
      "position": i + 1,
      "text": action,
    })),
  } : null;

  return (
    <main className="page container project-page">
      {jsonLd && (
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
        />
      )}
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "BreadcrumbList",
            itemListElement: [
              { "@type": "ListItem", position: 1, name: "Home", item: "https://droply.digital/" },
              { "@type": "ListItem", position: 2, name: "Airdrops", item: "https://droply.digital/airdrops" },
              { "@type": "ListItem", position: 3, name: p.name, item: `https://droply.digital/project/${p.slug}` },
            ],
          }).replace(/</g, "\\u003c"),
        }}
      />
      <Link href="/airdrops" className="back-link">&larr; All drops</Link>

      {/* A hard danger outranks everything else on the page, so it sits
          above the hero rather than inside the verification block. */}
      {verification?.alert ? (
        <div className="verify-alert" role="alert">{verification.alert}</div>
      ) : null}

      {/* --- Hero: logo + title + subtitle + badges on the left, single CTA on the right, same row --- */}
      <section className="project-hero project-hero--split">

        <div className="big-project-icon project-hero__icon">
          {p.logo ? <img src={p.logo} alt={`${p.name} logo`} /> : initials(p.name)}
        </div>

        <div className="project-hero__main">
          <div className="project-hero__status">
          <span className={`status-pill ${p.status.toLowerCase()}`}>{p.status}</span>
          {p.isLive && (
            <span className="project-hero__live">
              <span className="project-hero__live-dot" />
              Live now
            </span>
          )}
          {(p.lifeCycle === "funding" || p.lifeCycle === "scheduled") && (
            <span
              title="CryptoRank lists this project at a pre-token stage; token status may change"
              style={{
                display: "inline-flex",
                alignItems: "center",
                gap: 6,
                padding: "2px 10px",
                borderRadius: 999,
                fontSize: 12,
                fontWeight: 600,
                lineHeight: "18px",
                background: "rgba(234, 179, 8, 0.12)",
                color: "#b45309",
                border: "1px solid rgba(234, 179, 8, 0.35)",
                whiteSpace: "nowrap",
              }}
            >
              Pre-token (CryptoRank: {p.lifeCycle})
            </span>
          )}
        </div>
          <h1 className="project-hero__title">
            {p.name}
            {p.symbol ? <span className="ticker-tag">${p.symbol}</span> : null}
          </h1>

          <p className="project-hero__subtitle">{ov?.tagline || p.description}</p>

          {isCryptoRank ? null : (
            <ProjectBadges
            difficulty={p.difficulty}
            cost={p.costToFarm}
            chain={p.chain}
            audit={auditState}
            contract={contractState}
          />
          )}

          {p.requirements && p.requirements.length ? (
            <div className="req-pills">
              {p.requirements.map((r) => <span key={r} className="type-pill">{r}</span>)}
            </div>
          ) : null}

          {p.source && <small className="muted project-hero__source">Source: {p.source}</small>}
        </div>

        {p.claimUrl && (
          <a
            href={p.claimUrl}
            target="_blank"
            rel="noreferrer"
            className="primary-btn primary-btn--hero project-hero__cta"
          >
            <Rocket size={18} />
            Start Now
          </a>
        )}
      </section>

      {metaLine ? <p className="project-meta muted">{metaLine}</p> : null}

      {isCryptoRank ? <CryptoRankDetails project={p} /> : null}

      {steps.length || (isCryptoRank && p.tasks && p.tasks.length) || official.length || social.length ? (
        <div className="guide-layout">
          {steps.length ? (
            <section className="article-card guide-layout__steps">
              <GuideSteps actions={steps} slug={p.slug} />
            </section>
          ) : isCryptoRank && p.tasks && p.tasks.length ? (
            <section className="article-card guide-layout__steps">
              <CryptoRankTasks tasks={p.tasks} slug={p.slug} sourceUrl={p.sourceUrl} />
            </section>
          ) : null}

          {official.length || social.length ? (
            <section className="article-card guide-layout__links">
              <LinksPanel official={official} social={social} />
            </section>
          ) : null}
        </div>
      ) : null}

      {ov && (ov.summary || ov.risks?.length || ov.notes?.length) ? (
        <section className="article-card take-card" aria-labelledby="take-title">
          <h2 id="take-title" className="take-card__title">Our take on {p.name}</h2>
          {ov.summary ? <p>{ov.summary}</p> : null}
          {ov.risks?.length ? (
            <>
              <h3>Risks to consider</h3>
              <ul>
                {ov.risks.map((r) => (
                  <li key={r}>{r}</li>
                ))}
              </ul>
            </>
          ) : null}
          {ov.notes?.length ? (
            <>
              <h3>Notes on the steps</h3>
              <ul>
                {ov.notes.map((n) => (
                  <li key={n}>{n}</li>
                ))}
              </ul>
            </>
          ) : null}
          {ov.updatedAt ? (
            <p className="muted take-card__updated">Reviewed {fmtLongDate(ov.updatedAt)}</p>
          ) : null}
        </section>
      ) : null}
      {faqItems.length ? (
        <section className="article-card faq-card" aria-labelledby="faq-title">
          <h2 id="faq-title" className="faq-card__title">
            {p.name} airdrop: frequently asked questions
          </h2>
          <div className="faq-list">
            {faqItems.map((f, i) => (
              <details key={f.q} className="faq-item" open={i === 0}>
                <summary>{f.q}</summary>
                <p>{f.a}</p>
              </details>
            ))}
          </div>
        </section>
      ) : null}

      {/* Verification now sits after the guide: someone following the
          steps has already seen the essentials up top (badges), this is
          the deeper detail for those who want it. */}
      <VerificationBlock verification={verification} />

      {timeline.length > 0 ? (
        <section className="article-card" aria-labelledby="history-title">
          <h2 id="history-title" className="faq-card__title">Status history</h2>
          <ul style={{ listStyle: "none", padding: 0, margin: 0, display: "grid", gap: 10 }}>
            {timeline.map((t) => (
              <li key={t.key}>
                <strong>{t.dateLabel}</strong>{" \u00b7 "}{t.label}
              </li>
            ))}
          </ul>
        </section>
      ) : null}

      {related.length ? (
        <section className="article-card related-card" aria-labelledby="related-title">
          <h2 id="related-title" className="related-card__title">Similar airdrops</h2>
          <div className="related-list">
            {related.map((o: any) => (
              <Link key={o.slug} href={`/project/${o.slug}`} className="related-item">
                <span className="related-item__name" style={{ display: "inline-flex", alignItems: "center", gap: 8 }}><ProjectLogo src={o.logo} name={o.name} size={22} />{o.name}</span>
                <span className="related-item__meta">
                  {o.status}
                  {o.chain ? <>{" \u00b7 "}<ChainIcon chain={o.chain} size={14} inline />{o.chain}</> : null}
                </span>
              </Link>
            ))}
          </div>
        </section>
      ) : null}
    </main>
  );
}
