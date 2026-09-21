// Shared types for the verification layer.
//
// Three files feed this:
//   data/verification.generated.ts — written by scripts/verify.js (daily)
//   data/verification.manual.ts    — hand-written, always wins
//   lib/verification.ts            — merges them and exposes the lookup

/** Every claim is one of three states. "unverified" and "not_found"
 *  are deliberately different: the first means we didn't look (or
 *  couldn't confirm), the second means we looked and there is nothing. */
export type CheckStatus = "confirmed" | "unverified" | "not_found";

export type RiskLevel = "Low" | "Medium" | "High" | "Unknown";

/** Nothing is shown as confirmed without a source and a date. */
export interface Evidence {
  sourceUrl?: string;
  /** Short human label for the source: "Etherscan", "DefiLlama", "Manual". */
  sourceLabel?: string;
  /** ISO date (YYYY-MM-DD) of when this claim was last checked. */
  checkedAt?: string;
}

export type LinkKind = "website" | "x" | "discord" | "telegram" | "docs";

export interface LinkCheck extends Evidence {
  kind: LinkKind;
  url?: string;
  status: CheckStatus;
  /** Why it's in this state, in user-facing words:
   *  "Linked from the official site and links back". */
  note?: string;
}

export interface ContractCheck extends Evidence {
  chain?: string;
  address?: string;
  /** Source verification on the explorer (not a security claim). */
  sourceVerified?: boolean;
  status: CheckStatus;
  note?: string;
}

export interface AuditCheck extends Evidence {
  auditor?: string;
  reportUrl?: string;
  /** ISO date of the report itself, not of our check. */
  date?: string;
  /** What the audit actually covered. An audit with no scope is weak evidence. */
  scope?: string;
  status: CheckStatus;
}

export interface FundingRound extends Evidence {
  round?: string;
  amountUsd?: number;
  date?: string;
  investors?: string[];
}

/** A risk signal is a fact, not a verdict. The verdict is computed
 *  from the signals below by scoreRisk(). */
export interface RiskSignal extends Evidence {
  code: RiskCode;
  /** User-facing one-liner. */
  label: string;
  /** true = the bad thing is present, false = checked and absent,
   *  undefined = not checked. */
  present?: boolean;
}

export type RiskCode =
  | "domain_new"
  | "domain_very_new"
  | "unsafe_browsing"
  | "link_mismatch"
  | "token_approval"
  | "no_audit"
  | "anon_team"
  | "no_contract_source"
  | "lookalike_domain";

export interface ProjectVerification {
  slug: string;
  /** ISO date of the most recent check of any section. */
  checkedAt: string;
  links: LinkCheck[];
  contracts: ContractCheck[];
  audits: AuditCheck[];
  funding: FundingRound[];
  signals: RiskSignal[];
  /** Computed by scoreRisk(); stored so the UI doesn't recompute. */
  risk: RiskVerdict;
  /** Set by verify.js when a hard danger is found. Renders as the red banner. */
  alert?: string;
}

export interface RiskVerdict {
  level: RiskLevel;
  score: number;
  /** The rules that fired, in the order they fired. Shown in the UI
   *  so the score can be explained instead of trusted. */
  reasons: string[];
}

/* =========================
   Risk rules
   One table, so the score is explainable and easy to argue with.
========================= */

export const RISK_RULES: Record<RiskCode, { points: number; reason: string }> = {
  unsafe_browsing: { points: 5, reason: "Flagged by Google Safe Browsing" },
  lookalike_domain: { points: 4, reason: "Domain imitates a known project" },
  token_approval: { points: 2, reason: "Asks for a token approval, not a signature" },
  domain_very_new: { points: 2, reason: "Domain registered less than 30 days ago" },
  link_mismatch: { points: 2, reason: "Official links do not reference each other" },
  domain_new: { points: 1, reason: "Domain registered less than 6 months ago" },
  no_audit: { points: 1, reason: "No public audit found" },
  anon_team: { points: 1, reason: "Team is anonymous" },
  no_contract_source: { points: 1, reason: "Contract source is not verified on the explorer" },
};

/** 0–1 Low, 2–3 Medium, 4+ High. Unknown when we checked too little
 *  to say anything — better an honest "Unknown" than a green Low. */
export const MIN_SIGNALS_FOR_VERDICT = 3;

export function scoreRisk(signals: RiskSignal[]): RiskVerdict {
  const checked = signals.filter((s) => s.present !== undefined);

  if (checked.length < MIN_SIGNALS_FOR_VERDICT) {
    return { level: "Unknown", score: 0, reasons: ["Not enough checks completed"] };
  }

  let score = 0;
  const reasons: string[] = [];

  for (const signal of checked) {
    if (!signal.present) continue;

    const rule = RISK_RULES[signal.code];

    if (!rule) continue;

    score += rule.points;
    reasons.push(rule.reason);
  }

  // domain_very_new implies domain_new; don't charge for both.
  if (
    reasons.includes(RISK_RULES.domain_very_new.reason) &&
    reasons.includes(RISK_RULES.domain_new.reason)
  ) {
    score -= RISK_RULES.domain_new.points;
    reasons.splice(reasons.indexOf(RISK_RULES.domain_new.reason), 1);
  }

  const level: RiskLevel = score >= 4 ? "High" : score >= 2 ? "Medium" : "Low";

  if (!reasons.length) {
    reasons.push("No risk signals found");
  }

  return { level, score, reasons };
}

/* =========================
   Staleness
========================= */

export const RECHECK_AFTER_DAYS = 30;

export function isStale(checkedAt?: string, now = new Date()): boolean {
  if (!checkedAt) return true;

  const then = new Date(checkedAt);

  if (Number.isNaN(then.getTime())) return true;

  return (now.getTime() - then.getTime()) / 86_400_000 > RECHECK_AFTER_DAYS;
}

/* =========================
   Merge: manual wins, section by section
========================= */

export type VerificationMap = Record<string, ProjectVerification>;

/** Manual data overrides the generated data per *section*, not per file,
 *  so a hand-checked audit list doesn't wipe the automatic link checks.
 *  An empty array in the manual file is treated as "no override";
 *  use `[]` plus `overrides: ["audits"]` to deliberately blank a section. */
export interface ManualVerification extends Partial<ProjectVerification> {
  slug: string;
  overrides?: (keyof ProjectVerification)[];
}

export function mergeVerification(
  generated: ProjectVerification[],
  manual: ManualVerification[]
): VerificationMap {
  const map: VerificationMap = {};

  for (const entry of generated) {
    map[entry.slug] = entry;
  }

  for (const entry of manual) {
    const base: ProjectVerification =
      map[entry.slug] ||
      {
        slug: entry.slug,
        checkedAt: entry.checkedAt || "",
        links: [],
        contracts: [],
        audits: [],
        funding: [],
        signals: [],
        risk: { level: "Unknown", score: 0, reasons: [] },
      };

    const merged: ProjectVerification = { ...base };
    const forced = new Set(entry.overrides || []);

    for (const key of ["links", "contracts", "audits", "funding", "signals"] as const) {
      const value = entry[key];

      if (!value) continue;
      if (!value.length && !forced.has(key)) continue;

      // @ts-expect-error — keys are checked above, arrays are same-shaped
      merged[key] = value;
    }

    if (entry.alert !== undefined) merged.alert = entry.alert;
    if (entry.checkedAt) merged.checkedAt = entry.checkedAt;

    // Manual signals change the score, so always recompute unless the
    // manual file states a verdict itself.
    merged.risk = entry.risk || scoreRisk(merged.signals);

    map[entry.slug] = merged;
  }

  return map;
}

/** Small summary used by the /airdrops cards and the "verified only" filter. */
export interface VerificationBadge {
  linksVerified: boolean;
  audited: boolean;
  risk: RiskLevel;
  stale: boolean;
}

export function toBadge(v?: ProjectVerification): VerificationBadge | undefined {
  if (!v) return undefined;

  return {
    linksVerified: v.links.some((l) => l.kind === "website" && l.status === "confirmed"),
    audited: v.audits.some((a) => a.status === "confirmed"),
    risk: v.risk.level,
    stale: isStale(v.checkedAt),
  };
}
