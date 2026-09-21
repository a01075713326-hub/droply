# add-cryptorank-page.ps1  (ASCII only)
# Adds a CryptoRank-only data block to the project page.
# Projects from Airdrops.io / AirdropAlert keep their current page untouched.
#   1) creates components\CryptoRankDetails.tsx
#   2) patches app\project\[slug]\page.tsx (4 small insertions, checked before writing)
#   3) appends .cr-* styles to app\globals.css
# Backups of page.tsx / globals.css are made next to the originals.

$ErrorActionPreference = "Stop"
$root  = "C:\Users\Sasa\Desktop\zip"
$page  = Join-Path $root "app\project\[slug]\page.tsx"
$comp  = Join-Path $root "components\CryptoRankDetails.tsx"
$css   = Join-Path $root "app\globals.css"
$enc   = New-Object System.Text.UTF8Encoding($false)
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

foreach ($f in @($page, $css)) {
  if (-not (Test-Path -LiteralPath $f)) { Write-Host "Not found: $f"; exit 1 }
}

# ---------------- component source ----------------
$tsx = @'
import { ArrowUpRight } from "lucide-react";
import type { Project } from "@/data/projects";

type Investor = {
  name?: string;
  tier?: number | null;
  category?: string;
  is_lead?: boolean;
};

type Stat = { label: string; value: string };

function compactUsd(value?: string): string | null {
  if (!value) return null;
  const n = Number(String(value).replace(/[^0-9.]/g, ""));
  if (!Number.isFinite(n) || n <= 0) return value;
  const s = new Intl.NumberFormat("en-US", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(n);
  return "$" + s;
}

export default function CryptoRankDetails({ project: p }: { project: Project }) {
  const investors = (Array.isArray(p.topInvestors) ? p.topInvestors : []) as Investor[];

  const stats: Stat[] = [];
  const add = (label: string, value: unknown) => {
    if (value === undefined || value === null || value === "") return;
    stats.push({ label, value: String(value) });
  };

  add("Activity points", p.activityPoints);
  add("Rating", p.rating);
  add("Cost to farm", p.costToFarm);
  add("Time to farm", p.timeToFarm);
  add("Reward type", p.rewardType);
  add("Total funding", compactUsd(p.funding));
  add("Investors", p.investorCount);
  add(
    "Twitter followers",
    p.twitterFollowers != null ? p.twitterFollowers.toLocaleString("en-US") : null
  );
  add("Twitter score", p.twitterScore);

  return (
    <section className="cr-details" aria-label="CryptoRank data">
      <div className="cr-details__head">
        <h2 className="cr-details__title">CryptoRank data</h2>
        {p.sourceUrl ? (
          <a className="cr-details__link" href={p.sourceUrl} target="_blank" rel="noreferrer">
            Open on CryptoRank <ArrowUpRight size={14} />
          </a>
        ) : null}
      </div>

      {stats.length ? (
        <div className="cr-stats">
          {stats.map((s) => (
            <div key={s.label} className="cr-stat">
              <span className="cr-stat__label">{s.label}</span>
              <strong className="cr-stat__value">{s.value}</strong>
            </div>
          ))}
        </div>
      ) : null}

      <div className="cr-flags">
        {p.noActiveTask != null ? (
          <span className={"cr-flag " + (p.noActiveTask ? "cr-flag--warn" : "cr-flag--ok")}>
            {p.noActiveTask ? "No active task" : "Task active"}
          </span>
        ) : null}
        {p.isAuthProtected != null ? (
          <span className="cr-flag">Auth protected: {p.isAuthProtected ? "yes" : "no"}</span>
        ) : null}
      </div>

      {p.activityTypes && p.activityTypes.length ? (
        <div className="cr-block">
          <h3 className="cr-block__title">Activity types</h3>
          <div className="cr-chips">
            {p.activityTypes.map((t) => (
              <span key={t} className="type-pill">{t}</span>
            ))}
          </div>
        </div>
      ) : null}

      {investors.length ? (
        <div className="cr-block">
          <h3 className="cr-block__title">
            Top investors
            {p.investorCount ? " (" + investors.length + " of " + p.investorCount + ")" : ""}
          </h3>
          <ul className="cr-investors">
            {investors.map((inv, i) => (
              <li key={(inv.name ?? "investor") + i} className="cr-investor">
                <span className="cr-investor__name">{inv.name}</span>
                <span className="cr-investor__meta">
                  {inv.category ? <span>{inv.category}</span> : null}
                  {inv.tier != null ? <span className="cr-badge">Tier {inv.tier}</span> : null}
                  {inv.is_lead ? <span className="cr-badge cr-badge--lead">Lead</span> : null}
                </span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}
'@

# ---------------- css source ----------------
$cssBlock = @'

/* cryptorank-details */
.cr-details { margin-top: 24px; padding: 22px; border-radius: 18px; background: rgba(255,255,255,.04); border: 1px solid rgba(255,255,255,.1); }
.cr-details__head { display: flex; align-items: center; justify-content: space-between; gap: 12px; flex-wrap: wrap; margin-bottom: 16px; }
.cr-details__title { margin: 0; font-size: 18px; }
.cr-details__link { display: inline-flex; align-items: center; gap: 4px; font-size: 13px; font-weight: 600; color: #c4a1ff; text-decoration: none; }
.cr-details__link:hover { text-decoration: underline; }
.cr-stats { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 10px; }
.cr-stat { display: flex; flex-direction: column; gap: 4px; padding: 12px 14px; border-radius: 12px; background: rgba(255,255,255,.04); border: 1px solid rgba(255,255,255,.08); }
.cr-stat__label { font-size: 12px; opacity: .6; }
.cr-stat__value { font-size: 17px; }
.cr-flags { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 14px; }
.cr-flag { font-size: 12px; padding: 5px 10px; border-radius: 999px; background: rgba(255,255,255,.06); border: 1px solid rgba(255,255,255,.12); }
.cr-flag--ok { color: #7ee2a8; border-color: rgba(126,226,168,.35); }
.cr-flag--warn { color: #ffcf7a; border-color: rgba(255,207,122,.35); }
.cr-block { margin-top: 20px; }
.cr-block__title { margin: 0 0 10px; font-size: 14px; opacity: .8; }
.cr-chips { display: flex; flex-wrap: wrap; gap: 8px; }
.cr-investors { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
.cr-investor { display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 10px 14px; border-radius: 12px; background: rgba(255,255,255,.03); border: 1px solid rgba(255,255,255,.07); }
.cr-investor__name { font-weight: 600; }
.cr-investor__meta { display: flex; align-items: center; justify-content: flex-end; flex-wrap: wrap; gap: 8px; font-size: 12px; opacity: .85; }
.cr-badge { padding: 2px 8px; border-radius: 999px; background: rgba(255,255,255,.08); }
.cr-badge--lead { background: rgba(168,85,247,.25); color: #e2ccff; }
'@

# ---------------- read + check page anchors (nothing is written yet) ----------------
$orig = [System.IO.File]::ReadAllText($page, $enc)
$nl = "`n"
if ($orig.Contains("`r`n")) { $nl = "`r`n" }
$t = $orig.Replace("`r`n", "`n")

$patchPage = -not $t.Contains("CryptoRankDetails")
if ($patchPage) {
  $mImport = [regex]::Match($t, '(?m)^import LinksPanel[^\n]*$')
  $mConst  = [regex]::Match($t, '(?m)^[ \t]*const verification = getVerification\(p\.slug\);[ \t]*$')
  $mBadges = [regex]::Match($t, '<ProjectBadges\b[\s\S]*?/>')
  $mGuide  = [regex]::Match($t, '\{\(p\.actions && p\.actions\.length\) \|\| official\.length')

  $missing = @()
  if (-not $mImport.Success) { $missing += "import LinksPanel line" }
  if (-not $mConst.Success)  { $missing += "const verification = getVerification(p.slug);" }
  if (-not $mBadges.Success) { $missing += "<ProjectBadges ... />" }
  if (-not $mGuide.Success)  { $missing += "{(p.actions && p.actions.length) || official.length ..." }
  if ($missing.Count -gt 0) {
    Write-Host "Anchors not found in page.tsx - nothing was changed:"
    $missing | ForEach-Object { Write-Host ("  - " + $_) }
    exit 1
  }
}
else {
  Write-Host "page.tsx already mentions CryptoRankDetails - skipping page patch"
}

# ---------------- write everything ----------------
# 1) component
if (Test-Path -LiteralPath $comp) { Copy-Item -LiteralPath $comp -Destination "$comp.$stamp.bak" }
[System.IO.File]::WriteAllText($comp, $tsx.Replace("`r`n", "`n"), $enc)
Write-Host "Wrote components\CryptoRankDetails.tsx"

# 2) page.tsx (apply from the bottom of the file to the top so indexes stay valid)
if ($patchPage) {
  Copy-Item -LiteralPath $page -Destination "$page.$stamp.bak"

  $t = $t.Insert($mGuide.Index, '{isCryptoRank ? <CryptoRankDetails project={p} /> : null}' + "`n`n      ")

  $badgesNew = '{isCryptoRank ? null : (' + "`n" + '            ' + $mBadges.Value + "`n" + '          )}'
  $t = $t.Substring(0, $mBadges.Index) + $badgesNew + $t.Substring($mBadges.Index + $mBadges.Length)

  $constLine = "`n" + '  const isCryptoRank = String(p.source || "").toLowerCase().includes("cryptorank");'
  $t = $t.Insert($mConst.Index + $mConst.Length, $constLine)

  $importLine = "`n" + 'import CryptoRankDetails from "@/components/CryptoRankDetails";'
  $t = $t.Insert($mImport.Index + $mImport.Length, $importLine)

  [System.IO.File]::WriteAllText($page, $t.Replace("`n", $nl), $enc)
  Write-Host "Patched app\project\[slug]\page.tsx (backup: page.tsx.$stamp.bak)"
}

# 3) css
$cssText = [System.IO.File]::ReadAllText($css, $enc)
if ($cssText.Contains("cryptorank-details")) {
  Write-Host "globals.css already has the .cr-* block - skipping"
}
else {
  Copy-Item -LiteralPath $css -Destination "$css.$stamp.bak"
  [System.IO.File]::AppendAllText($css, $cssBlock.Replace("`r`n", "`n"), $enc)
  Write-Host "Appended .cr-* styles to app\globals.css (backup: globals.css.$stamp.bak)"
}

# ---------------- optional type check ----------------
Push-Location $root
try {
  if (Test-Path ".\node_modules\.bin\tsc.cmd") {
    Write-Host ""
    Write-Host "Running: npx tsc --noEmit (may take a little while)"
    & npx tsc --noEmit
    if ($LASTEXITCODE -eq 0) { Write-Host "TypeScript: OK" } else { Write-Host "TypeScript reported errors above - send them to me" }
  }
}
finally { Pop-Location }

Write-Host ""
Write-Host "Done. Run: npm run dev  and open /project/ekiden"
