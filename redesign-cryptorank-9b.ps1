# redesign-cryptorank-9b.ps1 (part 2: own content, similar projects, dates)
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File .\redesign-cryptorank-9b.ps1
#
# What it does:
#   1. Creates lib\overrides.ts (server-only reader for data\overrides.json)
#   2. Creates data\overrides.json (starter with an _example entry, ignored by the site)
#   3. Patches app\project\[slug]\page.tsx:
#        - "Our take" block (summary / risks / notes) only for projects that have an override
#        - override.summary is used as the meta description, override.tagline as the hero subtitle
#        - "Similar airdrops" block (same chain / category) for internal links
#        - "Tracked on Droply since ..." and "Reviewed ..." line
#   4. Appends styles next to .faq-card
# sync.js is NOT touched: overrides live in their own file, so sync cannot overwrite them.
# Backups: *.bak-redesign9b
# NOTE: ASCII-only on purpose.

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Patch([string]$text, [string]$old, [string]$new, [string]$label) {
  $n = [regex]::Matches($text, [regex]::Escape($old)).Count
  if ($n -ne 1) {
    Write-Host "NOT FOUND (or more than one match): $label (found: $n)" -ForegroundColor Yellow
    return $null
  }
  return $text.Replace($old, $new)
}

$pagePath = '.\app\project\[slug]\page.tsx'
if (-not (Test-Path -LiteralPath $pagePath)) {
  Write-Host "File $pagePath not found. Run this from the project root." -ForegroundColor Red
  exit 1
}
$page = (Resolve-Path -LiteralPath $pagePath).Path
$src = [System.IO.File]::ReadAllText($page, [System.Text.Encoding]::UTF8)

if ($src.Contains('getOverride')) {
  Write-Host 'Already applied (getOverride found in page.tsx). Nothing to do.' -ForegroundColor Green
  exit 0
}

# ---------- 1. lib\overrides.ts ----------
$libFile = '.\lib\overrides.ts'
if (-not (Test-Path -LiteralPath $libFile)) {
  $libCode = @'
import fs from "node:fs";
import path from "node:path";

/* Hand-written content per project, kept in data/overrides.json.
   sync.js never touches that file, so this text survives every sync.
   Server-only (uses fs): import it from server components, not client ones. */

export type ProjectOverride = {
  /** Short line for the hero (replaces the generic source description). */
  tagline?: string;
  /** Your own overview. Also used as the meta description. */
  summary?: string;
  /** Real risks, one short sentence each. */
  risks?: string[];
  /** Nuances of the steps that the source guide does not mention. */
  notes?: string[];
  /** YYYY-MM-DD, when you last reviewed this project. */
  updatedAt?: string;
};

export function getOverride(slug: string): ProjectOverride | undefined {
  try {
    const file = path.join(process.cwd(), "data", "overrides.json");
    const raw = fs.readFileSync(file, "utf8").replace(/^\uFEFF/, "");
    const data = JSON.parse(raw) as Record<string, ProjectOverride>;
    return Object.prototype.hasOwnProperty.call(data, slug) ? data[slug] : undefined;
  } catch {
    return undefined;
  }
}
'@
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'lib\overrides.ts'), $libCode, $utf8)
  Write-Host 'Created lib\overrides.ts' -ForegroundColor Green
} else {
  Write-Host 'lib\overrides.ts already exists, left as is.' -ForegroundColor Yellow
}

# ---------- 2. data\overrides.json ----------
$jsonFile = '.\data\overrides.json'
if (-not (Test-Path -LiteralPath $jsonFile)) {
  $jsonCode = @'
{
  "_readme": "One entry per project slug. All fields are optional. Keys starting with _ are ignored by the site. Write only facts you checked yourself.",
  "_example": {
    "tagline": "One short line about what the project does.",
    "summary": "2-4 sentences in your own words: what it is, what actually earns points, who it fits.",
    "risks": [
      "No public audit found at the time of review.",
      "Points are not a confirmed token allocation."
    ],
    "notes": [
      "Something the source guide does not mention about a step."
    ],
    "updatedAt": "2026-09-20"
  }
}
'@
  [System.IO.File]::WriteAllText((Join-Path (Get-Location) 'data\overrides.json'), $jsonCode, $utf8)
  Write-Host 'Created data\overrides.json' -ForegroundColor Green
} else {
  Write-Host 'data\overrides.json already exists, left as is.' -ForegroundColor Yellow
}

# ---------- 3. page.tsx ----------

# 3a. import
$s = Patch $src 'import { getVerification } from "@/lib/verification";' ('import { getVerification } from "@/lib/verification";' + "`r`n" + 'import { getOverride } from "@/lib/overrides";') 'import getOverride'
if ($null -eq $s) { exit 1 }

# 3b. getRelated helper
$related = @'
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
'@
$s = Patch $s 'type FaqItem = { q: string; a: string };' ($related + "`r`n`r`n" + 'type FaqItem = { q: string; a: string };') 'insert getRelated'
if ($null -eq $s) { exit 1 }

# 3c. meta description from the override summary
$metaNew = @'
const ov = getOverride(p.slug);
  const description = ov?.summary
    ? ov.summary.length > 158
      ? ov.summary.slice(0, 155).trimEnd() + "\u2026"
      : ov.summary
    : buildDescription(p);
'@
$s = Patch $s 'const description = buildDescription(p);' $metaNew.TrimEnd() 'meta description'
if ($null -eq $s) { exit 1 }

# 3d. variables in the page component
$varsNew = @'
const ov = getOverride(p.slug);
  const allProjects = await getProjects();
  const related = getRelated(p, allProjects);
  const metaLine = [
    p.firstSeenAt ? "Tracked on Droply since " + fmtLongDate(p.firstSeenAt) : "",
    ov?.updatedAt ? "Reviewed " + fmtLongDate(ov.updatedAt) : "",
  ]
    .filter(Boolean)
    .join(" \u00b7 ");
  const faqItems = buildFaq(p);
'@
$s = Patch $s 'const faqItems = buildFaq(p);' $varsNew.TrimEnd() 'page variables'
if ($null -eq $s) { exit 1 }

# 3e. hero subtitle
$s = Patch $s '<p className="project-hero__subtitle">{p.description}</p>' '<p className="project-hero__subtitle">{ov?.tagline || p.description}</p>' 'hero subtitle'
if ($null -eq $s) { exit 1 }

# 3f. tracked / reviewed line after the hero
$metaBlock = @'
{metaLine ? <p className="project-meta muted">{metaLine}</p> : null}
'@
$s = Patch $s '{isCryptoRank ? <CryptoRankDetails project={p} /> : null}' ($metaBlock.TrimEnd() + "`r`n`r`n      " + '{isCryptoRank ? <CryptoRankDetails project={p} /> : null}') 'meta line'
if ($null -eq $s) { exit 1 }

# 3g. "Our take" block before the FAQ
$takeBlock = @'
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

'@
$s = Patch $s '{faqItems.length ? (' ($takeBlock.TrimStart() + '      {faqItems.length ? (') 'Our take block'
if ($null -eq $s) { exit 1 }

# 3h. Similar projects after the verification block
$relBlock = @'
<VerificationBlock verification={verification} />

      {related.length ? (
        <section className="article-card related-card" aria-labelledby="related-title">
          <h2 id="related-title" className="related-card__title">Similar airdrops</h2>
          <div className="related-list">
            {related.map((o: any) => (
              <Link key={o.slug} href={`/project/${o.slug}`} className="related-item">
                <span className="related-item__name">{o.name}</span>
                <span className="related-item__meta">
                  {o.status}
                  {o.chain ? ` \u00b7 ${o.chain}` : ""}
                </span>
              </Link>
            ))}
          </div>
        </section>
      ) : null}
'@
$s = Patch $s '<VerificationBlock verification={verification} />' $relBlock.TrimEnd() 'Similar projects block'
if ($null -eq $s) { exit 1 }

# ---------- Write page ----------
Copy-Item -LiteralPath $page "${page}.bak-redesign9b"
[System.IO.File]::WriteAllText($page, $s, $utf8)
Write-Host 'page.tsx updated.' -ForegroundColor Green

# ---------- 4. Styles ----------
$css = Get-ChildItem -Path .\app, .\components, .\styles -Recurse -File -Include *.css -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch 'node_modules|\\\.next\\' } |
  Where-Object { Select-String -LiteralPath $_.FullName -Pattern 'faq-card' -Quiet } |
  Select-Object -First 1

if (-not $css) {
  Write-Host 'CSS file with .faq-card not found. Styles were NOT added; tell me and I will send them.' -ForegroundColor Yellow
  exit 0
}

$cssText = [System.IO.File]::ReadAllText($css.FullName, [System.Text.Encoding]::UTF8)
if (-not $cssText.Contains('.take-card')) {
  Copy-Item -LiteralPath $css.FullName "$($css.FullName).bak-redesign9b"
  $add = @'

/* redesign-9b: own take, similar projects, meta line */
.project-meta {
  margin: 10px 0 0;
  font-size: 12px;
}
.take-card__title,
.related-card__title {
  font-size: 20px;
  margin: 0 0 12px;
}
.take-card p,
.take-card li {
  font-size: 14px;
  line-height: 1.65;
}
.take-card h3 {
  font-size: 14px;
  margin: 16px 0 6px;
  opacity: 0.85;
}
.take-card ul {
  margin: 0;
  padding-left: 20px;
}
.take-card__updated {
  margin-top: 14px;
  font-size: 12px;
}
.related-list {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 10px;
}
.related-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
  padding: 12px 14px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  color: inherit;
  text-decoration: none;
}
.related-item:hover {
  border-color: rgba(255, 255, 255, 0.28);
}
.related-item__name {
  font-weight: 600;
}
.related-item__meta {
  font-size: 12px;
  opacity: 0.65;
}
'@
  [System.IO.File]::WriteAllText($css.FullName, $cssText + $add, $utf8)
  Write-Host "Styles added to $($css.FullName)" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Done. Now:' -ForegroundColor Green
Write-Host '  1. Run npm run dev and open /project/baibai - you should see "Tracked on Droply since ..." and "Similar airdrops".'
Write-Host '  2. Add your own entry to data\overrides.json (copy _example, rename it to the slug, e.g. "baibai").'
Write-Host '  3. In production, overrides are read at build time: rebuild after editing the file.'
