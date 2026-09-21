#requires -Version 5.1
$ErrorActionPreference = "Stop"

$root = Get-Location
Write-Host "Working in $root" -ForegroundColor Cyan

$componentsDir = Join-Path $root "components"
$pagePath      = Join-Path $root "app\project\[slug]\page.tsx"
$cssPath       = Join-Path $root "app\globals.css"

foreach ($p in @($pagePath, $cssPath)) {
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND: $p" -ForegroundColor Red
    Write-Host "Run this script from the repo root (zipv222/)." -ForegroundColor Red
    exit 1
  }
}
if (-not (Test-Path -LiteralPath $componentsDir)) { New-Item -ItemType Directory -Path $componentsDir | Out-Null }

# ---------------------------------------------------------------
# 1. components/ProjectBadges.tsx
# ---------------------------------------------------------------
$badgesPath = Join-Path $componentsDir "ProjectBadges.tsx"
$badgesContent = @'
import {
  TrendingUp,
  Wallet,
  Boxes,
  ShieldCheck,
  ShieldAlert,
  FileCheck2,
  FileX2,
} from "lucide-react";
import type { ReactNode } from "react";

export type BadgeState = "ok" | "warn" | "unknown";

type Tone = "neutral" | "ok" | "warn";

type Badge = {
  icon: ReactNode;
  value: string;
  label: string;
  tone: Tone;
};

export default function ProjectBadges({
  difficulty,
  cost,
  chain,
  audit,
  contract,
}: {
  difficulty?: string;
  cost?: string;
  chain: string;
  /** "ok" = audit found, "warn" = none found, "unknown" = not checked */
  audit: BadgeState;
  /** "ok" = contract verified, "warn" = not verified, "unknown" = no contract on file */
  contract: BadgeState;
}) {
  const badges: Badge[] = [
    {
      icon: <TrendingUp size={17} />,
      value: (difficulty || "Unknown").toUpperCase(),
      label: "Difficulty",
      tone: "neutral",
    },
    {
      icon: <Wallet size={17} />,
      value: (cost || "Unknown").toUpperCase(),
      label: "Cost",
      tone: "neutral",
    },
    {
      icon: <Boxes size={17} />,
      value: chain.toUpperCase(),
      label: "Blockchain",
      tone: "neutral",
    },
    audit === "ok"
      ? {
          icon: <ShieldCheck size={17} />,
          value: "AUDITED",
          label: "Security",
          tone: "ok" as Tone,
        }
      : {
          icon: <ShieldAlert size={17} />,
          value: "NO AUDIT",
          label: audit === "warn" ? "Warning" : "Not checked",
          tone: audit === "warn" ? ("warn" as Tone) : ("neutral" as Tone),
        },
    contract === "ok"
      ? {
          icon: <FileCheck2 size={17} />,
          value: "CONTRACT",
          label: "Verified",
          tone: "ok" as Tone,
        }
      : {
          icon: <FileX2 size={17} />,
          value: "NO CONTRACT",
          label: contract === "warn" ? "Unverified" : "Not checked",
          tone: contract === "warn" ? ("warn" as Tone) : ("neutral" as Tone),
        },
  ];

  return (
    <div className="badge-row">
      {badges.map((b) => (
        <div key={b.label + b.value} className={`badge badge-${b.tone}`}>
          <span className="badge-icon">{b.icon}</span>
          <div>
            <b>{b.value}</b>
            <span>{b.label}</span>
          </div>
        </div>
      ))}
    </div>
  );
}
'@
Set-Content -LiteralPath $badgesPath -Value $badgesContent -Encoding UTF8
Write-Host "Wrote $badgesPath" -ForegroundColor Green

# ---------------------------------------------------------------
# 2. components/LinksPanel.tsx
# ---------------------------------------------------------------
$linksPath = Join-Path $componentsDir "LinksPanel.tsx"
$linksContent = @'
"use client";

import { useState } from "react";
import {
  Globe,
  Gift,
  BookOpen,
  FileText,
  Link2,
  Send,
  MessageCircle,
  Copy,
  Check,
} from "lucide-react";

export type PanelLink = {
  kind:
    | "website"
    | "claim"
    | "docs"
    | "whitepaper"
    | "x"
    | "telegram"
    | "discord";
  title: string;
  url: string;
};

const ICONS = {
  website: Globe,
  claim: Gift,
  docs: BookOpen,
  whitepaper: FileText,
  x: XIcon,
  telegram: Send,
  discord: MessageCircle,
} as const;

/** lucide has no X/Twitter glyph, so this is the official mark as a path. */
function XIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
    </svg>
  );
}

function shortUrl(url: string) {
  try {
    const u = new URL(url);
    const path = u.pathname === "/" ? "" : u.pathname;
    return u.host.replace(/^www\./, "") + path;
  } catch {
    return url;
  }
}

function Row({ link }: { link: PanelLink }) {
  const [copied, setCopied] = useState(false);
  const Icon = ICONS[link.kind];

  async function copy() {
    try {
      await navigator.clipboard.writeText(link.url);
      setCopied(true);
      setTimeout(() => setCopied(false), 1400);
    } catch {
      /* clipboard blocked -- the row is still a working link */
    }
  }

  return (
    <div className="link-row">
      <a
        href={link.url}
        target="_blank"
        rel="noreferrer"
        className="link-row-main"
      >
        <span className="link-row-icon">
          <Icon size={16} />
        </span>
        <span className="link-row-text">
          <b>{link.title}</b>
          <small>{shortUrl(link.url)}</small>
        </span>
      </a>
      <button
        type="button"
        onClick={copy}
        className="link-copy"
        aria-label={`Copy ${link.title} link`}
      >
        {copied ? <Check size={15} /> : <Copy size={15} />}
      </button>
    </div>
  );
}

export default function LinksPanel({
  official,
  social,
}: {
  official: PanelLink[];
  social: PanelLink[];
}) {
  if (!official.length && !social.length) return null;

  return (
    <div className="links-panel">
      {official.length > 0 && (
        <div className="links-group">
          <div className="section-kicker">
            <Link2 size={13} /> OFFICIAL LINKS
          </div>
          {official.map((l) => (
            <Row key={l.url + l.kind} link={l} />
          ))}
        </div>
      )}

      {social.length > 0 && (
        <div className="links-group">
          <div className="section-kicker">
            <Link2 size={13} /> SOCIAL LINKS
          </div>
          {social.map((l) => (
            <Row key={l.url + l.kind} link={l} />
          ))}
        </div>
      )}
    </div>
  );
}
'@
Set-Content -LiteralPath $linksPath -Value $linksContent -Encoding UTF8
Write-Host "Wrote $linksPath" -ForegroundColor Green

# ---------------------------------------------------------------
# 3. Append CSS to app/globals.css (skip if already applied)
# ---------------------------------------------------------------
$cssMarker = "/* === Badge row + links panel"
$existingCss = Get-Content -LiteralPath $cssPath -Raw
if ($existingCss -notmatch [regex]::Escape($cssMarker)) {
  $cssBlock = @'


/* === Badge row + links panel -- appended by apply-baibai-blocks.ps1 === */

.badge-row {
  display: grid;
  grid-template-columns: repeat(5, 1fr);
  gap: 10px;
  margin: 0 0 45px;
}

.badge {
  display: flex;
  align-items: center;
  gap: 11px;
  padding: 13px 14px;
  border: 1px solid rgba(255, 255, 255, 0.09);
  border-radius: 14px;
  background: rgba(255, 255, 255, 0.025);
  transition: 0.2s ease;
}

.badge:hover {
  background: rgba(255, 255, 255, 0.05);
  transform: translateY(-1px);
}

.badge-icon {
  display: grid;
  place-items: center;
  flex: none;
  width: 34px;
  height: 34px;
  border-radius: 10px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.04);
  color: #9eafff;
}

.badge b {
  display: block;
  font-size: 12.5px;
  letter-spacing: 0.3px;
  white-space: nowrap;
}

.badge span:last-child {
  display: block;
  margin-top: 3px;
  font-size: 11.5px;
  color: #697587;
}

.badge-ok {
  border-color: rgba(91, 224, 181, 0.28);
  background: rgba(91, 224, 181, 0.06);
}

.badge-ok .badge-icon {
  border-color: rgba(91, 224, 181, 0.3);
  background: rgba(91, 224, 181, 0.12);
  color: #5be0b5;
}

.badge-ok b {
  color: #5be0b5;
}

.badge-warn {
  border-color: rgba(255, 92, 110, 0.32);
  background: rgba(255, 92, 110, 0.07);
}

.badge-warn .badge-icon {
  border-color: rgba(255, 92, 110, 0.3);
  background: rgba(255, 92, 110, 0.12);
  color: #ff8a96;
}

.badge-warn b {
  color: #ff8a96;
}

/* --- links panel --- */

.links-panel {
  display: flex;
  flex-direction: column;
  gap: 22px;
}

.links-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.links-group .section-kicker {
  margin-bottom: 4px;
  color: #9eafff;
}

.link-row {
  display: flex;
  align-items: stretch;
  gap: 8px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.025);
  padding: 4px 4px 4px 0;
  transition: 0.2s ease;
}

.link-row:hover {
  background: rgba(255, 255, 255, 0.05);
  border-color: rgba(139, 92, 246, 0.3);
}

.link-row-main {
  display: flex;
  align-items: center;
  gap: 11px;
  flex: 1 1 auto;
  min-width: 0;
  padding: 8px 0 8px 10px;
}

.link-row-icon {
  display: grid;
  place-items: center;
  flex: none;
  width: 32px;
  height: 32px;
  border-radius: 9px;
  border: 1px solid rgba(255, 255, 255, 0.08);
  background: rgba(255, 255, 255, 0.04);
  color: #dbe8ff;
}

.link-row-text {
  min-width: 0;
}

.link-row-text b {
  display: block;
  font-size: 13px;
}

.link-row-text small {
  display: block;
  margin-top: 2px;
  font-size: 11.5px;
  color: #697587;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.link-copy {
  flex: none;
  width: 38px;
  margin: 4px 4px 4px 0;
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 9px;
  background: rgba(255, 255, 255, 0.03);
  color: #8d98a8;
  cursor: pointer;
  display: grid;
  place-items: center;
  transition: 0.18s ease;
}

.link-copy:hover {
  background: rgba(255, 255, 255, 0.08);
  color: #eef2f8;
}

@media (max-width: 1050px) {
  .badge-row {
    grid-template-columns: repeat(3, 1fr);
  }
}

@media (max-width: 760px) {
  .badge-row {
    grid-template-columns: repeat(2, 1fr);
    margin-bottom: 30px;
  }
}
'@
  Add-Content -LiteralPath $cssPath -Value $cssBlock -Encoding UTF8
  Write-Host "Appended CSS block to $cssPath" -ForegroundColor Green
} else {
  Write-Host "CSS block already present in $cssPath, skipping" -ForegroundColor Yellow
}

# ---------------------------------------------------------------
# 4. Patch app/project/[slug]/page.tsx
# ---------------------------------------------------------------
$page = Get-Content -LiteralPath $pagePath -Raw

if ($page -match "ProjectBadges") {
  Write-Host "page.tsx already patched, skipping" -ForegroundColor Yellow
} else {
  # 4a. imports
  $importAnchor = 'import VerificationBlock from "@/components/VerificationBlock";'
  $importReplacement = $importAnchor + "`r`nimport ProjectBadges, { type BadgeState } from `"@/components/ProjectBadges`";`r`nimport LinksPanel, { type PanelLink } from `"@/components/LinksPanel`";"
  if ($page -notmatch [regex]::Escape($importAnchor)) {
    throw "Could not find import anchor in page.tsx -- file may have changed. Aborting patch."
  }
  $page = $page.Replace($importAnchor, $importReplacement)

  # 4b. compute badge state + link arrays, right after verification lookup
  $verifyAnchor = "  const verification = getVerification(p.slug);"
  $verifyReplacement = @'
  const verification = getVerification(p.slug);

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
'@
  if ($page -notmatch [regex]::Escape($verifyAnchor)) {
    throw "Could not find verification anchor in page.tsx -- file may have changed. Aborting patch."
  }
  $page = $page.Replace($verifyAnchor, $verifyReplacement)

  # 4c. insert badge row right after the metrics-grid block
  $metricsAnchor = @'
      <div className="metrics-grid">
        <div><span>EVENT</span><b>{p.event}</b></div>
        <div><span>DIFFICULTY</span><b>{p.difficulty || "\u2014"}</b></div>
        <div><span>COST TO FARM</span><b>{p.costToFarm || "\u2014"}</b></div>
        <div><span>BLOCKCHAIN</span><b>{p.chain}</b></div>
      </div>
'@
  $metricsReplacement = $metricsAnchor + @'

      <ProjectBadges
        difficulty={p.difficulty}
        cost={p.costToFarm}
        chain={p.chain}
        audit={auditState}
        contract={contractState}
      />
'@
  if ($page -notmatch [regex]::Escape($metricsAnchor)) {
    throw "Could not find metrics-grid anchor in page.tsx -- file may have changed. Aborting patch."
  }
  $page = $page.Replace($metricsAnchor, $metricsReplacement)

  # 4d. replace the old flat LINKS section + `hasLinks` with the new panel
  $hasLinksAnchor = "  const hasLinks = p.x || p.telegram || p.discord || p.whitepaper || p.docs;`r`n`r`n  return ("
  # (handled separately below because it spans return statement boundary)

  $oldHasLinksLine = "const hasLinks = p.x || p.telegram || p.discord || p.whitepaper || p.docs;`r`n`r`n  return ("
  if ($page -match [regex]::Escape("const hasLinks = p.x || p.telegram || p.discord || p.whitepaper || p.docs;")) {
    $page = $page -replace [regex]::Escape("const hasLinks = p.x || p.telegram || p.discord || p.whitepaper || p.docs;`r`n`r`n  return \("), "return ("
  }

  $oldLinksSection = @'
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
'@
  $newLinksSection = @'
      {official.length || social.length ? (
        <section className="article-card" style={{ marginTop: 22 }}>
          <LinksPanel official={official} social={social} />
        </section>
      ) : null}
'@
  if ($page -notmatch [regex]::Escape($oldLinksSection)) {
    throw "Could not find LINKS section anchor in page.tsx -- file may have changed. Aborting patch."
  }
  $page = $page.Replace($oldLinksSection, $newLinksSection)

  Set-Content -LiteralPath $pagePath -Value $page -Encoding UTF8 -NoNewline
  Write-Host "Patched $pagePath" -ForegroundColor Green
}

Write-Host ""
Write-Host "Done. Now run:  npm run dev" -ForegroundColor Cyan
Write-Host "Check app/project/[slug]/page.tsx manually -- the audit/contract" -ForegroundColor Yellow
Write-Host "logic near the top is a guess based on class names in globals.css;" -ForegroundColor Yellow
Write-Host "fix the field names once you confirm data/verification.ts's shape." -ForegroundColor Yellow
