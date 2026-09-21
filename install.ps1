<#
  Droply — установка слоя верификации.

  Запуск из корня репозитория:
      powershell -ExecutionPolicy Bypass -File .\install.ps1

  Или с явным путём:
      powershell -ExecutionPolicy Bypass -File .\install.ps1 -Repo "C:\code\droply"

  Скрипт создаёт новые файлы, а те два, что уже есть в репозитории
  (lib\projects.ts и app\project\[slug]\page.tsx), сохраняет рядом
  как .bak перед заменой. Ничего не удаляет и не коммитит.
#>

param(
  [string]$Repo = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath (Join-Path $Repo "package.json"))) {
  Write-Host "В $Repo нет package.json. Укажите папку репозитория через -Repo." -ForegroundColor Red
  exit 1
}

# UTF-8 без BOM: BOM ломает первый import в .ts при некоторых настройках сборки.
$enc = New-Object System.Text.UTF8Encoding($false)

function Write-Repo-File {
  param([string]$RelPath, [string]$Content, [switch]$Backup)

  $full = Join-Path $Repo $RelPath
  $dir  = Split-Path $full -Parent

  # -LiteralPath везде: в пути есть [slug], а без него PowerShell
  # считает скобки шаблоном и не находит существующий файл.
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
  }

  if (Test-Path -LiteralPath $full) {
    if ($Backup) {
      $bak = "$full.bak"
      Copy-Item -LiteralPath $full -Destination $bak -Force
      Write-Host ("  замена  {0}  (старая версия -> {1})" -f $RelPath, (Split-Path $bak -Leaf)) -ForegroundColor Yellow
    } else {
      Write-Host ("  пропуск {0}  (уже существует)" -f $RelPath) -ForegroundColor DarkGray
      return
    }
  } else {
    Write-Host ("  создан  {0}" -f $RelPath) -ForegroundColor Green
  }

  [System.IO.File]::WriteAllText($full, $Content, $enc)
}

Write-Host ""
Write-Host "Droply: слой верификации -> $Repo" -ForegroundColor Cyan
Write-Host ""

$data_verification_ts = @'
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

'@
Write-Repo-File -RelPath "data\verification.ts" -Content $data_verification_ts

$data_verification_manual_ts = @'
// Hand-checked data. Wins over data/verification.generated.ts,
// section by section. Never overwritten by any workflow — edit freely.
//
// Rules:
//   - anything marked "confirmed" must carry sourceUrl + checkedAt
//   - leaving a section out means "keep whatever the script found"
//   - to deliberately blank a section, pass [] and list it in `overrides`

import type { ManualVerification } from "./verification";

export const manualVerification: ManualVerification[] = [
  {
    slug: "example-project",
    checkedAt: "2026-09-18",
    links: [
      {
        kind: "website",
        url: "https://example.xyz",
        status: "confirmed",
        note: "Site links to the X account and the account links back",
        sourceUrl: "https://example.xyz",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
      {
        kind: "x",
        url: "https://x.com/exampleproject",
        status: "confirmed",
        sourceUrl: "https://x.com/exampleproject",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
    ],
    contracts: [
      {
        status: "not_found",
        note: "No token contract published yet",
        checkedAt: "2026-09-18",
        sourceLabel: "Manual",
      },
    ],
    audits: [
      {
        auditor: "Example Audits",
        reportUrl: "https://exampleaudits.io/reports/example.pdf",
        date: "2026-04-02",
        scope: "Staking contracts only, commit 8f21c0a",
        status: "confirmed",
        sourceUrl: "https://exampleaudits.io/reports/example.pdf",
        sourceLabel: "Example Audits",
        checkedAt: "2026-09-18",
      },
    ],
    signals: [
      {
        code: "anon_team",
        label: "Team members are named with photos and LinkedIn profiles",
        present: false,
        sourceUrl: "https://example.xyz/team",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
    ],
  },
];

'@
Write-Repo-File -RelPath "data\verification.manual.ts" -Content $data_verification_manual_ts

$lib_verification_ts = @'
import {
  mergeVerification,
  toBadge,
  type ProjectVerification,
  type VerificationBadge,
  type VerificationMap,
} from "@/data/verification";
import { generatedVerification } from "@/data/verification.generated";
import { manualVerification } from "@/data/verification.manual";

// Merged once per process. Both inputs are static files committed to
// the repo, so there's nothing to invalidate at runtime.
let cache: VerificationMap | null = null;

function all(): VerificationMap {
  if (!cache) {
    cache = mergeVerification(generatedVerification, manualVerification);
  }

  return cache;
}

export function getVerification(slug: string): ProjectVerification | undefined {
  return all()[slug];
}

export function getBadge(slug: string): VerificationBadge | undefined {
  return toBadge(all()[slug]);
}

/** For the /airdrops list: one pass, no per-card lookups. */
export function getBadges(): Record<string, VerificationBadge> {
  const out: Record<string, VerificationBadge> = {};

  for (const [slug, entry] of Object.entries(all())) {
    const badge = toBadge(entry);

    if (badge) out[slug] = badge;
  }

  return out;
}

export function isVerified(slug: string): boolean {
  return Boolean(getBadge(slug)?.linksVerified);
}

'@
Write-Repo-File -RelPath "lib\verification.ts" -Content $lib_verification_ts

$components_VerificationBlock_tsx = @'
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
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="verify-section">
      <div className="section-kicker">{title}</div>
      {children}
    </div>
  );
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

      <Section title="CONTRACT">
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

      <Section title="AUDIT">
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
      </Section>
    </section>
  );
}

'@
Write-Repo-File -RelPath "components\VerificationBlock.tsx" -Content $components_VerificationBlock_tsx

$scripts_verify_js = @'
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
import fs from "node:fs/promises";

/* =========================
   Config
========================= */

const DATA_DIR = path.join(__dirname, "..", "data");
const GENERATED = path.join(DATA_DIR, "projects.generated.ts");
const OUT = path.join(DATA_DIR, "verification.generated.ts");
const CACHE = path.join(DATA_DIR, ".verify-cache.json");

// Re-checking every project every day is wasteful and rude to the
// sites we fetch. A project is re-checked only if its cache entry is
// older than this, or if its website/x/discord changed in sync.
const RECHECK_AFTER_DAYS = Number(process.env.VERIFY_RECHECK_DAYS || 7);

// Hard cap per run so a growing project list can't turn into a
// multi-hour job. Oldest cache entries go first.
const MAX_PER_RUN = Number(process.env.VERIFY_MAX_PER_RUN || 120);

const CONCURRENCY = 4;
const FETCH_TIMEOUT_MS = 12_000;

const DEFILLAMA_PROTOCOLS = "https://api.llama.fi/protocols";
const RDAP = (domain) => `https://rdap.org/domain/${domain}`;
const SAFE_BROWSING =
  "https://safebrowsing.googleapis.com/v4/threatMatches:find";

const UA = "Mozilla/5.0 (compatible; Droply.digital verifier/1.0)";

const today = () => new Date().toISOString().slice(0, 10);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const daysSince = (iso) => {
  if (!iso) return Infinity;

  const then = new Date(iso).getTime();

  if (Number.isNaN(then)) return Infinity;

  return (Date.now() - then) / 86_400_000;
};

/* =========================
   Fetch helpers
========================= */

// Never let one hanging site stall the whole run, and never throw:
// a failed check is "unverified", not a crashed workflow.
async function get(url, { headers = {}, json = false } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const r = await fetch(url, {
      headers: { "User-Agent": UA, Accept: json ? "application/json" : "text/html,*/*", ...headers },
      redirect: "follow",
      signal: controller.signal,
    });

    if (!r.ok) return { ok: false, status: r.status, url: r.url };

    const body = json ? await r.json() : await r.text();

    return { ok: true, status: r.status, url: r.url, body };
  } catch (error) {
    return { ok: false, status: 0, error: error?.message || "request failed" };
  } finally {
    clearTimeout(timer);
  }
}

async function post(url, payload) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const r = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    if (!r.ok) return { ok: false, status: r.status };

    return { ok: true, body: await r.json() };
  } catch (error) {
    return { ok: false, status: 0, error: error?.message || "request failed" };
  } finally {
    clearTimeout(timer);
  }
}

/* =========================
   URL / domain helpers
========================= */

const hostOf = (url) => {
  try {
    return new URL(url).hostname.replace(/^www\./i, "").toLowerCase();
  } catch {
    return "";
  }
};

// example.co.uk -> example.co.uk, app.example.xyz -> example.xyz.
// Deliberately naive; RDAP tolerates a subdomain miss by 404ing, and
// we fall back to the full host in that case.
const registrableOf = (host) => {
  const parts = host.split(".");

  if (parts.length <= 2) return host;

  const twoLevelTlds = /^(co|com|org|net|gov|ac)\.[a-z]{2}$/i;
  const tail = parts.slice(-2).join(".");

  return twoLevelTlds.test(tail) ? parts.slice(-3).join(".") : tail;
};

const handleOf = (url) => {
  const match = String(url || "").match(
    /^https?:\/\/(?:www\.)?(?:x|twitter)\.com\/([A-Za-z0-9_]{1,15})/i
  );

  return match ? match[1].toLowerCase() : "";
};

/* =========================
   Site parsing
========================= */

const X_RE = /https?:\/\/(?:www\.)?(?:x|twitter)\.com\/([A-Za-z0-9_]{1,15})(?![A-Za-z0-9_])/gi;
const DISCORD_RE = /https?:\/\/(?:www\.)?discord(?:\.gg|\.com\/invite)\/[A-Za-z0-9-]+/gi;
const TELEGRAM_RE = /https?:\/\/(?:www\.)?t\.me\/[A-Za-z0-9_+]+/gi;
const DOCS_RE = /https?:\/\/[^"'\s<>]*(?:docs?|gitbook|whitepaper)[^"'\s<>]*/gi;

// Handles that appear on half the web and say nothing about the project.
const IGNORED_HANDLES = new Set([
  "intent", "share", "home", "i", "search", "hashtag",
  "elonmusk", "x", "twitter", "vercel", "nextjs", "github",
]);

function extractSiteLinks(html) {
  const uniq = (matches) => [...new Set(matches.map((m) => m[0]))];

  const xHandles = [
    ...new Set(
      [...html.matchAll(X_RE)]
        .map((m) => m[1].toLowerCase())
        .filter((h) => !IGNORED_HANDLES.has(h))
    ),
  ];

  return {
    x: xHandles,
    discord: uniq([...html.matchAll(DISCORD_RE)]),
    telegram: uniq([...html.matchAll(TELEGRAM_RE)]),
    docs: uniq([...html.matchAll(DOCS_RE)]).slice(0, 3),
  };
}

/* =========================
   Checks
========================= */

// The strongest free signal: the site points at a social profile and
// that profile points back at the same domain. A phishing clone copies
// the site but can't make the real X account link to its domain.
//
// x.com blocks unauthenticated page fetches, so this returns
// "unverified" far more often than it returns "confirmed". That's the
// honest outcome — never downgrade a failed fetch into a mismatch.
async function backlinkCheck(profileUrl, domain) {
  const r = await get(profileUrl);

  if (!r.ok) {
    return { status: "unverified", note: "Profile could not be read automatically" };
  }

  const body = String(r.body).toLowerCase();

  if (body.includes(domain)) {
    return { status: "confirmed", note: "Profile links back to the official domain" };
  }

  return { status: "unverified", note: "No link back to the domain found on the profile" };
}

// Registration age via RDAP. Free, no key, works for most gTLDs.
// Some ccTLDs have no RDAP server — that's "unknown", not "new".
async function domainAge(domain) {
  const r = await get(RDAP(domain), { json: true });

  if (!r.ok) return { ageDays: undefined, source: RDAP(domain) };

  const events = r.body?.events || [];
  const registered = events.find(
    (e) => String(e.eventAction).toLowerCase() === "registration"
  )?.eventDate;

  if (!registered) return { ageDays: undefined, source: RDAP(domain) };

  return { ageDays: Math.floor(daysSince(registered)), registered, source: RDAP(domain) };
}

async function safeBrowsing(urls) {
  const key = process.env.GOOGLE_SAFE_BROWSING_KEY;

  if (!key || !urls.length) return { checked: false, hits: [] };

  const r = await post(`${SAFE_BROWSING}?key=${key}`, {
    client: { clientId: "droply-digital", clientVersion: "1.0" },
    threatInfo: {
      threatTypes: ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE"],
      platformTypes: ["ANY_PLATFORM"],
      threatEntryTypes: ["URL"],
      threatEntries: urls.map((url) => ({ url })),
    },
  });

  if (!r.ok) return { checked: false, hits: [] };

  return { checked: true, hits: r.body?.matches || [] };
}

// DefiLlama is the only free public source with audit links attached
// to protocols. Coverage is mostly protocols with TVL, so most
// early-stage airdrop projects simply aren't there.
async function loadDefiLlama() {
  const r = await get(DEFILLAMA_PROTOCOLS, { json: true });

  if (!r.ok) {
    console.warn(`DefiLlama: skipped (HTTP ${r.status})`);
    return { byDomain: new Map(), byHandle: new Map() };
  }

  const byDomain = new Map();
  const byHandle = new Map();

  for (const p of r.body || []) {
    const domain = registrableOf(hostOf(p.url || ""));
    const handle = String(p.twitter || "").toLowerCase();

    if (domain && !byDomain.has(domain)) byDomain.set(domain, p);
    if (handle && !byHandle.has(handle)) byHandle.set(handle, p);
  }

  console.log(`DefiLlama: loaded ${byDomain.size} protocols`);

  return { byDomain, byHandle };
}

function auditsFrom(protocol) {
  if (!protocol) return [];

  const links = Array.isArray(protocol.audit_links) ? protocol.audit_links : [];

  return links.filter(Boolean).map((url) => ({
    auditor: hostOf(url) || undefined,
    reportUrl: url,
    scope: undefined,
    status: "confirmed",
    sourceUrl: `https://defillama.com/protocol/${protocol.slug}`,
    sourceLabel: "DefiLlama",
    checkedAt: today(),
  }));
}

/* =========================
   Per-project verification
========================= */

async function verifyProject(project, llama) {
  const checkedAt = today();
  const links = [];
  const signals = [];
  const audits = [];
  const funding = [];
  const contracts = [];

  let alert;

  const website = project.website || "";
  const host = hostOf(website);
  const domain = registrableOf(host);

  if (!website || !host) {
    links.push({
      kind: "website",
      status: "not_found",
      note: "No official website in our sources",
      checkedAt,
    });
  } else {
    const site = await get(website);

    if (!site.ok) {
      links.push({
        kind: "website",
        url: website,
        status: "unverified",
        note: `Site did not respond (${site.status || site.error})`,
        sourceUrl: website,
        sourceLabel: "Site",
        checkedAt,
      });
    } else {
      // A redirect off the declared domain is worth surfacing: it's
      // normal for rebrands, and a red flag for cloned listings.
      const landedOn = registrableOf(hostOf(site.url));
      const redirected = landedOn && landedOn !== domain;

      links.push({
        kind: "website",
        url: site.url,
        status: "confirmed",
        note: redirected ? `Redirects to ${landedOn}` : "Site is reachable",
        sourceUrl: site.url,
        sourceLabel: "Site",
        checkedAt,
      });

      const found = extractSiteLinks(String(site.body));
      const effectiveDomain = landedOn || domain;

      // ---- X ----

      const listedHandle = handleOf(project.x);
      const siteHandle = found.x[0];

      if (siteHandle) {
        const url = `https://x.com/${siteHandle}`;
        const back = await backlinkCheck(url, effectiveDomain);

        const mismatch = Boolean(listedHandle && listedHandle !== siteHandle);

        links.push({
          kind: "x",
          url,
          status: mismatch ? "unverified" : back.status,
          note: mismatch
            ? `Our sources list @${listedHandle}, the site links @${siteHandle}`
            : back.note,
          sourceUrl: site.url,
          sourceLabel: "Site",
          checkedAt,
        });

        signals.push({
          code: "link_mismatch",
          label: mismatch
            ? "The X account on the site differs from the one in our listing"
            : "Site and listing point at the same X account",
          present: mismatch,
          sourceUrl: site.url,
          sourceLabel: "Site",
          checkedAt,
        });
      } else {
        links.push({
          kind: "x",
          url: project.x || undefined,
          status: project.x ? "unverified" : "not_found",
          note: project.x
            ? "Listed by an aggregator, not found on the official site"
            : "No X account found on the official site",
          sourceUrl: project.sourceUrl,
          sourceLabel: project.source,
          checkedAt,
        });
      }

      // ---- Discord / Telegram / docs ----

      for (const [kind, values, listed] of [
        ["discord", found.discord, project.discord],
        ["telegram", found.telegram, project.telegram],
        ["docs", found.docs, project.docs || project.whitepaper],
      ]) {
        const url = values[0] || listed;

        links.push({
          kind,
          url: url || undefined,
          status: values[0] ? "confirmed" : url ? "unverified" : "not_found",
          note: values[0]
            ? "Linked from the official site"
            : url
            ? "From an aggregator listing, not found on the official site"
            : undefined,
          sourceUrl: values[0] ? site.url : project.sourceUrl,
          sourceLabel: values[0] ? "Site" : project.source,
          checkedAt,
        });
      }
    }

    // ---- Domain age ----

    const age = await domainAge(domain);

    if (age.ageDays !== undefined) {
      signals.push({
        code: "domain_very_new",
        label:
          age.ageDays < 30
            ? `Domain registered ${age.ageDays} days ago`
            : `Domain registered ${Math.floor(age.ageDays / 30)} months ago`,
        present: age.ageDays < 30,
        sourceUrl: age.source,
        sourceLabel: "RDAP",
        checkedAt,
      });

      signals.push({
        code: "domain_new",
        label: `Domain age: ${age.ageDays} days`,
        present: age.ageDays < 180,
        sourceUrl: age.source,
        sourceLabel: "RDAP",
        checkedAt,
      });
    }

    // ---- Safe Browsing ----

    const candidates = [website, project.claimUrl].filter(Boolean);
    const sb = await safeBrowsing([...new Set(candidates)]);

    if (sb.checked) {
      const present = sb.hits.length > 0;

      signals.push({
        code: "unsafe_browsing",
        label: present
          ? "Google Safe Browsing flags this site"
          : "Clean in Google Safe Browsing",
        present,
        sourceUrl: "https://transparencyreport.google.com/safe-browsing/search",
        sourceLabel: "Safe Browsing",
        checkedAt,
      });

      if (present) {
        alert = "Google Safe Browsing flags this project's site as dangerous. Do not connect a wallet.";
      }
    }
  }

  // ---- Audits (DefiLlama) ----

  const protocol =
    (domain && llama.byDomain.get(domain)) ||
    (handleOf(project.x) && llama.byHandle.get(handleOf(project.x)));

  const llamaAudits = auditsFrom(protocol);

  if (llamaAudits.length) {
    audits.push(...llamaAudits);
  } else {
    audits.push({
      status: "not_found",
      sourceUrl: "https://defillama.com",
      sourceLabel: "DefiLlama",
      checkedAt,
    });
  }

  signals.push({
    code: "no_audit",
    label: llamaAudits.length
      ? `${llamaAudits.length} public audit report(s) found`
      : "No public audit found",
    present: llamaAudits.length === 0,
    sourceUrl: protocol
      ? `https://defillama.com/protocol/${protocol.slug}`
      : "https://defillama.com",
    sourceLabel: "DefiLlama",
    checkedAt,
  });

  // ---- Contract ----
  //
  // Deliberately not searched for: an address found by guessing is
  // worse than no address at all. Only the manual layer or official
  // docs put an address here; the explorer call then confirms it.

  contracts.push({
    status: "not_found",
    note: "No contract address on file",
    checkedAt,
  });

  // ---- Funding ----
  //
  // Whatever sync already found, carried over with its source. Rounds
  // from CryptoRank/RootData get added by the manual layer for now.

  if (project.funding) {
    funding.push({
      round: "Total raised",
      amountUsd: Number(String(project.funding).replace(/[^0-9.]/g, "")) || undefined,
      sourceUrl: project.sourceUrl,
      sourceLabel: project.source,
      checkedAt,
    });
  }

  return {
    slug: project.slug,
    checkedAt,
    links,
    contracts,
    audits,
    funding,
    signals,
    alert,
  };
}

/* =========================
   Project loading
========================= */

// Same regex trick as scripts/sync.js: this runs under plain Node and
// can't import a .ts module.
async function loadProjects() {
  const content = await fs.readFile(GENERATED, "utf8");
  const projects = [];

  const objectRegex = /\{[^{}]*\}/g;
  let match;

  const field = (block, name) =>
    block.match(new RegExp(`"${name}":\\s*"([^"]*)"`))?.[1] || "";

  while ((match = objectRegex.exec(content))) {
    const block = match[0];
    const slug = field(block, "slug");

    if (!slug) continue;

    projects.push({
      slug,
      name: field(block, "name"),
      website: field(block, "website"),
      x: field(block, "x"),
      discord: field(block, "discord"),
      telegram: field(block, "telegram"),
      docs: field(block, "docs"),
      whitepaper: field(block, "whitepaper"),
      claimUrl: field(block, "claimUrl"),
      funding: field(block, "funding"),
      source: field(block, "source"),
      sourceUrl: field(block, "sourceUrl"),
    });
  }

  return projects;
}

async function loadCache() {
  try {
    return JSON.parse(await fs.readFile(CACHE, "utf8"));
  } catch {
    return { entries: {} };
  }
}

/* =========================
   Run
========================= */

async function run() {
  const projects = await loadProjects();
  const cache = await loadCache();

  console.log(`Verify: ${projects.length} projects in projects.generated.ts`);

  // A project is re-checked when its cache entry is stale or when the
  // links sync found for it have changed since the last check.
  const fingerprint = (p) => [p.website, p.x, p.discord, p.claimUrl].join("|");

  const due = projects
    .filter((p) => {
      const entry = cache.entries[p.slug];

      if (!entry) return true;
      if (entry.fingerprint !== fingerprint(p)) return true;

      return daysSince(entry.checkedAt) > RECHECK_AFTER_DAYS;
    })
    .sort((a, b) => {
      const at = cache.entries[a.slug]?.checkedAt || "";
      const bt = cache.entries[b.slug]?.checkedAt || "";

      return at.localeCompare(bt);
    })
    .slice(0, MAX_PER_RUN);

  console.log(`Verify: ${due.length} due this run (cap ${MAX_PER_RUN})`);

  const llama = await loadDefiLlama();

  const results = new Map(
    Object.entries(cache.entries)
      .filter(([, entry]) => entry.result)
      .map(([slug, entry]) => [slug, entry.result])
  );

  let cursor = 0;

  const worker = async () => {
    while (true) {
      const index = cursor++;

      if (index >= due.length) return;

      const project = due[index];

      console.log(`Verify: ${index + 1}/${due.length} ${project.name || project.slug}`);

      const result = await verifyProject(project, llama);

      results.set(project.slug, result);

      cache.entries[project.slug] = {
        checkedAt: result.checkedAt,
        fingerprint: fingerprint(project),
        result,
      };

      await sleep(300);
    }
  };

  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, due.length) }, () => worker())
  );

  // Drop cache entries for projects that no longer exist.
  const live = new Set(projects.map((p) => p.slug));

  for (const slug of Object.keys(cache.entries)) {
    if (!live.has(slug)) {
      delete cache.entries[slug];
      results.delete(slug);
    }
  }

  const output = [...results.values()].sort((a, b) => a.slug.localeCompare(b.slug));

  await fs.writeFile(
    OUT,
    `// AUTO-GENERATED by scripts/verify.js. Do not edit.
// Hand-checked data belongs in data/verification.manual.ts.
import type { ProjectVerification } from "./verification";
import { scoreRisk } from "./verification";

const entries = ${JSON.stringify(output, null, 2)} as Omit<ProjectVerification, "risk">[];

export const generatedVerification: ProjectVerification[] = entries.map((e) => ({
  ...e,
  risk: scoreRisk(e.signals),
}));
`,
    "utf8"
  );

  await fs.writeFile(CACHE, JSON.stringify(cache, null, 2), "utf8");

  const alerts = output.filter((e) => e.alert);

  console.log("");
  console.log("=================================");
  console.log("Droply verification complete");
  console.log("=================================");
  console.log(`Checked this run: ${due.length}`);
  console.log(`Entries on file:  ${output.length}`);
  console.log(`Alerts:           ${alerts.length}`);
  console.log("=================================");

  for (const entry of alerts) {
    console.warn(`ALERT ${entry.slug}: ${entry.alert}`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  run();
}

export { extractSiteLinks, registrableOf, handleOf, auditsFrom };

'@
Write-Repo-File -RelPath "scripts\verify.js" -Content $scripts_verify_js

$_github_workflows_verify_yml = @'
name: Verify projects

on:
  schedule:
    # Daily, offset from the hourly sync so the two never race on data/.
    - cron: "40 3 * * *"
  workflow_dispatch:

# Two runs writing data/ at the same time would fight over the commit.
concurrency:
  group: droply-data
  cancel-in-progress: false

permissions:
  contents: write

jobs:
  verify:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 22

      - name: Run verification
        env:
          GOOGLE_SAFE_BROWSING_KEY: ${{ secrets.GOOGLE_SAFE_BROWSING_KEY }}
          VERIFY_MAX_PER_RUN: 120
        run: node scripts/verify.js

      - name: Commit results
        run: |
          git config user.name "droply-bot"
          git config user.email "bot@droply.digital"
          git add data/verification.generated.ts data/.verify-cache.json
          git diff --staged --quiet || git commit -m "chore: verification refresh"
          git push

'@
Write-Repo-File -RelPath ".github\workflows\verify.yml" -Content $_github_workflows_verify_yml

Write-Host ""
Write-Host "Файлы, которые уже были в репозитории:" -ForegroundColor Cyan

$lib_projects_ts = @'
import { projects as allProjects, type Project } from "@/data/projects";
import { getBadges } from "@/lib/verification";
import type { VerificationBadge } from "@/data/verification";

export async function getProjects(): Promise<Project[]> {
  return allProjects;
}

export async function getProject(slug: string) {
  const items = await getProjects();
  return items.find((project) => project.slug === slug);
}

/** Project list with its verification badge attached, for /airdrops.
 *  One merge pass instead of a lookup per card. */
export type ProjectWithBadge = Project & { verification?: VerificationBadge };

export async function getProjectsWithBadges(): Promise<ProjectWithBadge[]> {
  const badges = getBadges();
  const items = await getProjects();

  return items.map((project) => ({
    ...project,
    verification: badges[project.slug],
  }));
}

/** Used by the "verified only" filter. Verified means the official site
 *  check passed — not that the project is safe. */
export function isVerified(project: ProjectWithBadge) {
  return Boolean(project.verification?.linksVerified);
}

export function formatDate(date?: string) {
  if (!date) return "TBA";
  const parsed = new Date(`${date}T12:00:00`);
  if (Number.isNaN(parsed.getTime())) return "TBA";
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(parsed);
}

export function initials(name: string) { return name.slice(0, 2).toUpperCase(); }
export function truncate(text: string, max: number) {
  if (!text || text.length <= max) return text;
  const cut = text.slice(0, max);
  const lastSpace = cut.lastIndexOf(' ');
  return (lastSpace > 0 ? cut.slice(0, lastSpace) : cut).trim() + '...';
}

export function shortAction(text: string) {
  const parts = text.split(":");
  if (parts.length >= 2) return parts[1].trim();
  return text.length > 30 ? text.slice(0, 30).trim() + "..." : text;
}

export function cardActions(actions?: string[]) {
  if (!actions || !actions.length) return "";
  return actions.slice(0, 3).map(shortAction).join(", ");
}

'@
Write-Repo-File -RelPath "lib\projects.ts" -Content $lib_projects_ts -Backup

$app_project_slug_page_tsx = @'
import { notFound } from "next/navigation";
import { getProjects, getProject, initials } from "@/lib/projects";
import { getVerification } from "@/lib/verification";
import Link from "next/link";
import { ArrowUpRight } from "lucide-react";
import GuideSteps from "@/components/GuideSteps";
import FavoriteButton from "@/components/FavoriteButton";
import DeadlineBadge from "@/components/DeadlineBadge";
import VerificationBlock from "@/components/VerificationBlock";

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

  const verification = getVerification(p.slug);

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

      {/* A hard danger outranks everything else on the page, so it sits
          above the hero rather than inside the verification block. */}
      {verification?.alert ? (
        <div className="verify-alert" role="alert">{verification.alert}</div>
      ) : null}

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

      {/* Before the guide: someone about to follow the steps should see
          what we did and didn't verify first. */}
      <VerificationBlock verification={verification} />

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

'@
Write-Repo-File -RelPath "app\project\[slug]\page.tsx" -Content $app_project_slug_page_tsx -Backup

$css = @'
/* Verification block — append to globals.css.
   Uses the same glass surface as .article-card; only the pieces that
   don't exist yet are defined here. */

.verify-block {
  display: flex;
  flex-direction: column;
  gap: 18px;
}

.verify-alert {
  margin: -4px 0 0;
  padding: 12px 14px;
  border: 1px solid rgba(255, 92, 110, 0.35);
  border-radius: 12px;
  background: rgba(255, 92, 110, 0.12);
  color: #ffc4cb;
  font-size: 14px;
  line-height: 1.45;
}

.verify-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
}

.verify-head .section-kicker {
  margin: 0;
}

.verify-head-tags {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
}

.verify-risk {
  padding: 3px 10px;
  border-radius: 999px;
  border: 1px solid transparent;
  font-size: 12px;
  font-weight: 600;
}

.verify-risk.low {
  border-color: rgba(91, 224, 181, 0.3);
  background: rgba(91, 224, 181, 0.12);
  color: #5be0b5;
}

.verify-risk.medium {
  border-color: rgba(247, 195, 88, 0.3);
  background: rgba(247, 195, 88, 0.12);
  color: #f7c358;
}

.verify-risk.high {
  border-color: rgba(255, 92, 110, 0.35);
  background: rgba(255, 92, 110, 0.14);
  color: #ff8a96;
}

.verify-risk.unknown {
  border-color: rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.5);
}

.verify-stale {
  padding: 3px 10px;
  border-radius: 999px;
  border: 1px solid rgba(255, 255, 255, 0.14);
  background: rgba(255, 255, 255, 0.05);
  color: rgba(255, 255, 255, 0.55);
}

.verify-section {
  display: flex;
  flex-direction: column;
  gap: 10px;
  padding-top: 16px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
}

.verify-section .section-kicker {
  margin: 0;
}

.verify-row {
  display: flex;
  align-items: flex-start;
  gap: 10px;
}

.verify-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  flex: 0 0 auto;
  width: 20px;
  height: 20px;
  margin-top: 1px;
  border-radius: 50%;
  border: 1px solid transparent;
  font-size: 11px;
  font-weight: 700;
  line-height: 1;
}

.verify-icon.confirmed {
  border-color: rgba(91, 224, 181, 0.3);
  background: rgba(91, 224, 181, 0.12);
  color: #5be0b5;
}

.verify-icon.unverified {
  border-color: rgba(247, 195, 88, 0.3);
  background: rgba(247, 195, 88, 0.12);
  color: #f7c358;
}

.verify-icon.not_found {
  border-style: dashed;
  border-color: rgba(255, 255, 255, 0.18);
  background: transparent;
  color: rgba(255, 255, 255, 0.35);
}

.verify-row-body {
  display: flex;
  min-width: 0;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 2px;
}

.verify-row-title {
  overflow: hidden;
  font-size: 14px;
  color: rgba(255, 255, 255, 0.85);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.verify-row-title a {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  color: inherit;
  text-decoration: none;
}

.verify-row-title a:hover {
  color: #fff;
}

.verify-row-note {
  font-size: 12px;
  line-height: 1.45;
  color: rgba(255, 255, 255, 0.45);
  white-space: normal;
}

.verify-source {
  flex: 0 0 auto;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.4);
  text-decoration: none;
  border-bottom: 1px solid rgba(255, 255, 255, 0.18);
}

a.verify-source:hover {
  color: rgba(255, 255, 255, 0.75);
}

.verify-score-line {
  margin: 0;
  font-size: 14px;
  color: rgba(255, 255, 255, 0.6);
}

.verify-rules {
  margin: 0;
  padding: 0;
  list-style: none;
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.verify-rules li {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
  font-size: 12px;
  color: rgba(255, 255, 255, 0.3);
}

.verify-rules li.fired {
  color: rgba(255, 255, 255, 0.72);
}

.verify-rules li b {
  font-variant-numeric: tabular-nums;
}

/* Badges on /airdrops cards */

.verify-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: 999px;
  border: 1px solid rgba(91, 224, 181, 0.28);
  background: rgba(91, 224, 181, 0.1);
  color: #5be0b5;
  font-size: 11px;
  font-weight: 600;
}

.verify-badge.audit {
  border-color: rgba(138, 180, 255, 0.28);
  background: rgba(138, 180, 255, 0.1);
  color: #9cc0ff;
}

.verify-badge.risk-high {
  border-color: rgba(255, 92, 110, 0.35);
  background: rgba(255, 92, 110, 0.12);
  color: #ff8a96;
}

@media (max-width: 640px) {
  .verify-row {
    flex-wrap: wrap;
  }

  .verify-source {
    margin-left: 30px;
  }
}

'@

# ---- CSS ----
# Дописываем в globals.css один раз: повторный запуск ничего не дублирует.

$globals = @(
  "app\globals.css",
  "styles\globals.css",
  "src\app\globals.css"
) | ForEach-Object { Join-Path $Repo $_ } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

Write-Host ""

if ($globals) {
  $current = [System.IO.File]::ReadAllText($globals)

  if ($current -match "\.verify-block") {
    Write-Host "  пропуск globals.css (стили уже добавлены)" -ForegroundColor DarkGray
  } else {
    Copy-Item -LiteralPath $globals -Destination "$globals.bak" -Force
    [System.IO.File]::WriteAllText($globals, ($current.TrimEnd() + "`r`n`r`n" + $css + "`r`n"), $enc)
    Write-Host ("  дописан {0}" -f (Resolve-Path $globals -Relative)) -ForegroundColor Green
  }
} else {
  Write-Repo-File -RelPath "styles\verification.css" -Content $css
  Write-Host "  globals.css не найден — стили лежат в styles\verification.css, импортируйте их сами." -ForegroundColor Yellow
}

# ---- Заглушка для сгенерированного файла ----
# Без неё сборка упадёт на импорте, пока verify.js ни разу не отработал.

$stub = @'
// AUTO-GENERATED by scripts/verify.js. Do not edit.
import type { ProjectVerification } from "./verification";

export const generatedVerification: ProjectVerification[] = [];
'@

Write-Repo-File -RelPath "data\verification.generated.ts" -Content $stub

Write-Host ""
Write-Host "Готово." -ForegroundColor Cyan
Write-Host ""
Write-Host "Дальше:" -ForegroundColor Cyan
Write-Host "  1) npm run dev  — открыть любую страницу проекта, блок покажет 'Not checked yet'"
Write-Host "  2) `$env:VERIFY_MAX_PER_RUN=2; node scripts/verify.js  — пробный прогон на двух проектах"
Write-Host "  3) git status — посмотреть, что изменилось, .bak-файлы в коммит не класть"
Write-Host ""
