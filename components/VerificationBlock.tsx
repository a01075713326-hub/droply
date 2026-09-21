import { ArrowUpRight, Check, Minus } from "lucide-react";
import {
  isStale,
  RISK_RULES,
  type CheckStatus,
  type ProjectVerification,
  type RiskCode,
} from "@/data/verification";

/* Status marks. Three states on purpose: verified, looked-but-unsure,
   looked-and-nothing-there. */

const STATUS_LABEL: Record<CheckStatus, string> = {
  confirmed: "Verified",
  unverified: "Not cross-checked",
  not_found: "Nothing found",
};

function StatusIcon({ status }: { status: CheckStatus }) {
  return (
    <span className={`verify-icon ${status}`} title={STATUS_LABEL[status]} aria-label={STATUS_LABEL[status]}>
      {status === "confirmed" ? <Check size={12} strokeWidth={3} /> : status === "unverified" ? "?" : <Minus size={12} />}
    </span>
  );
}

function Source({ label, url }: { label?: string; url?: string }) {
  if (!label && !url) return null;

  let text = label;

  if (!text && url) {
    try {
      text = new URL(url).hostname.replace(/^www\./, "");
    } catch {
      text = "Source";
    }
  }

  return url ? (
    <a href={url} target="_blank" rel="noreferrer" className="verify-source">
      {text}
    </a>
  ) : (
    <span className="verify-source">{text}</span>
  );
}

function Row({
  status,
  title,
  note,
  href,
  source,
}: {
  status: CheckStatus;
  title: string;
  note?: string;
  href?: string;
  source?: { label?: string; url?: string };
}) {
  return (
    <div className="verify-row">
      <StatusIcon status={status} />
      <div className="verify-row-body">
        <span className="verify-row-title">
          {href ? (
            <a href={href} target="_blank" rel="noreferrer">
              {title} <ArrowUpRight size={12} />
            </a>
          ) : (
            title
          )}
        </span>
        {note ? <span className="verify-row-note">{note}</span> : null}
      </div>
      <Source label={source?.label} url={source?.url} />
    </div>
  );
}

function Section({
  title,
  tone,
  children,
}: {
  title: string;
  tone?: "danger" | "warning";
  children: React.ReactNode;
}) {
  return (
    <div className={`verify-section${tone ? ` verify-section--${tone}` : ""}`}>
      <div className="section-kicker">{title}</div>
      {children}
    </div>
  );
}

function hostOf(url?: string): string {
  if (!url) return "";
  try {
    return new URL(url).hostname.replace(/^www\./, "");
  } catch {
    return "";
  }
}

function fmtCheckedDate(value?: string): string {
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

/* Plain-language summary built only from what the checks actually found.
   It is real text (not a table), so people and search engines can read it. */
function buildSummary(v: ProjectVerification): string {
  const parts: string[] = [];

  const site = v.links.find((l) => l.kind === "website");
  const host = hostOf(site?.url);
  if (site && site.status === "confirmed") {
    parts.push(`The official website${host ? ` (${host})` : ""} was verified.`);
  } else if (site) {
    parts.push(`The official website${host ? ` (${host})` : ""} could not be verified.`);
  } else {
    parts.push("No official website has been checked.");
  }

  const socials = v.links.filter((l) => ["x", "discord", "telegram"].includes(l.kind));
  if (socials.length) {
    const ok = socials.filter((l) => l.status === "confirmed").length;
    if (ok === socials.length) {
      parts.push(`All ${socials.length} social links are confirmed by the official site.`);
    } else if (ok === 0) {
      parts.push(
        `${socials.length} social link${socials.length === 1 ? " has" : "s have"} not been cross-checked against the official site.`
      );
    } else {
      parts.push(`${ok} of ${socials.length} social links are confirmed by the official site; the rest are not.`);
    }
  }

  const hasAddress = v.contracts.some((c) => c.address);
  if (v.contracts.some((c) => c.address && c.status === "confirmed")) {
    parts.push("A contract address is on file and verified.");
  } else if (hasAddress) {
    parts.push("A contract address is on file but not verified.");
  } else {
    parts.push("No contract address is published.");
  }

  const audit = v.audits.find((a) => a.status === "confirmed");
  if (audit) {
    parts.push(`An audit${audit.auditor ? ` by ${audit.auditor}` : ""} was found.`);
  } else {
    parts.push("No public audit was found.");
  }

  if (v.risk.level === "Unknown") {
    parts.push("There are too few completed checks to assign a risk level.");
  } else {
    parts.push(`Overall risk: ${v.risk.level}.`);
  }

  const date = fmtCheckedDate(v.checkedAt);
  if (date) parts.push(`Checked on ${date}.`);

  return parts.join(" ");
}

const LINK_TITLE: Record<string, string> = {
  website: "Official website",
  x: "X account",
  discord: "Discord",
  telegram: "Telegram",
  docs: "Documentation",
};

export default function VerificationBlock({
  verification,
}: {
  verification?: ProjectVerification;
}) {
  /* No record for this slug: say so plainly instead of hiding the block,
     so "we didn't check" never looks like "we checked and it's fine". */
  if (!verification) {
    return (
      <section className="article-card verify-block">
        <div className="section-kicker">VERIFICATION</div>
        <div className="verify-row">
          <StatusIcon status="not_found" />
          <div className="verify-row-body">
            <span className="verify-row-title">Not checked yet</span>
            <span className="verify-row-note">
              We haven&rsquo;t verified this project&rsquo;s links, contract or audits. Check the
              official sources yourself before connecting a wallet.
            </span>
          </div>
        </div>
      </section>
    );
  }

  const { links, contracts, audits, funding, risk, alert, checkedAt } = verification;
  const stale = isStale(checkedAt);
  const summary = buildSummary(verification);
  const fired = new Set(verification.signals.filter((s) => s.present).map((s) => s.code));

  return (
    <section className="article-card verify-block">
      {alert ? <div className="verify-alert">{alert}</div> : null}

      <div className="verify-head">
        <div className="section-kicker">VERIFICATION</div>
        <div className="verify-head-tags">
          <span className={`verify-risk ${risk.level.toLowerCase()}`}>{risk.level} risk</span>
          {stale ? <span className="verify-stale">Needs recheck</span> : null}
          <span className="muted">Last checked {checkedAt || "\u2014"}</span>
        </div>
      </div>

      <p className="verify-summary">{summary}</p>

      <Section title="OFFICIAL LINKS">
        {links.length ? (
          links.map((link, i) => (
            <Row
              key={`${link.kind}-${i}`}
              status={link.status}
              title={link.url || LINK_TITLE[link.kind] || link.kind}
              note={link.note}
              href={link.url}
              source={{ label: link.sourceLabel, url: link.sourceUrl }}
            />
          ))
        ) : (
          <Row status="unverified" title="No links checked" />
        )}
      </Section>

      <Section title="CONTRACT" tone="danger">
        {contracts.map((contract, i) => (
          <Row
            key={i}
            status={contract.status}
            title={
              contract.address
                ? `${contract.chain ? `${contract.chain}: ` : ""}${contract.address}`
                : "No contract published"
            }
            note={
              contract.note ||
              (contract.sourceVerified === true
                ? "Source code verified on the explorer"
                : contract.sourceVerified === false
                ? "Source code is not verified on the explorer"
                : undefined)
            }
            href={contract.sourceUrl}
            source={{ label: contract.sourceLabel, url: contract.sourceUrl }}
          />
        ))}
      </Section>

      <Section title="AUDIT" tone="warning">
        {audits.map((audit, i) => (
          <Row
            key={i}
            status={audit.status}
            title={audit.auditor || "No audit found"}
            note={[audit.date, audit.scope].filter(Boolean).join(" \u00b7 ") || undefined}
            href={audit.reportUrl}
            source={{ label: audit.sourceLabel, url: audit.sourceUrl }}
          />
        ))}
      </Section>

      {funding.length ? (
        <Section title="FUNDING">
          {funding.map((round, i) => (
            <Row
              key={i}
              status="confirmed"
              title={[
                round.round,
                round.amountUsd ? `$${round.amountUsd.toLocaleString("en-US")}` : null,
              ]
                .filter(Boolean)
                .join(" \u2014 ")}
              note={round.investors?.length ? round.investors.join(", ") : round.date}
              source={{ label: round.sourceLabel, url: round.sourceUrl }}
            />
          ))}
        </Section>
      ) : null}

      {/* The score is shown as the whole rule table, so a user can see
          which rules fired instead of trusting a number. */}
      <Section title="HOW THIS SCORE WAS CALCULATED">
        <p className="verify-score-line">
          {risk.level === "Unknown"
            ? "Too few checks have been completed to give this project a risk level."
            : `${risk.score} point${risk.score === 1 ? "" : "s"} from the rules below.`}
        </p>
        <details className="verify-rules-details" open={risk.level !== "Unknown"}>
          <summary>Show all scoring rules</summary>
          <ul className="verify-rules">
          {(Object.entries(RISK_RULES) as [RiskCode, { points: number; reason: string }][]).map(
            ([code, rule]) => (
              <li key={code} className={fired.has(code) ? "fired" : ""}>
                <span>{rule.reason}</span>
                <b>{fired.has(code) ? `+${rule.points}` : "0"}</b>
              </li>
            )
          )}
        </ul>
        </details>
        <p className="verify-disclaimer">
          Automated assessment based on public data. It is not financial advice. Always check the
          official sources before connecting a wallet.
        </p>
      </Section>
    </section>
  );
}
