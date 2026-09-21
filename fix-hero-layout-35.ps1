$ErrorActionPreference = "Stop"

$root = "C:\Users\Sasa\Desktop\zip"
Set-Location $root

$pagePath = ".\app\project\[slug]\page.tsx"
$cssPath  = ".\app\project\[slug]\hero-redesign.css"

if (-not (Test-Path -LiteralPath $pagePath)) { Write-Host "STOP: page.tsx not found at $pagePath"; exit 1 }

Copy-Item -LiteralPath $pagePath -Destination "$pagePath.bak-35" -Force

# ---------------------------------------------------------------
# 1. Import the new CSS file from page.tsx (respects "use client")
# ---------------------------------------------------------------
$page = Get-Content -LiteralPath $pagePath -Raw -Encoding UTF8

$importLine = 'import "./hero-redesign.css";'
if ($page -notmatch [regex]::Escape($importLine)) {
  $lines = $page -split "`r?`n", 2
  if ($lines[0] -match '^\s*["'']use (client|server)["'']\s*;?\s*$') {
    $page = $lines[0] + "`r`n" + $importLine + "`r`n" + $lines[1]
  } else {
    $page = $importLine + "`r`n" + $page
  }
  Set-Content -LiteralPath $pagePath -Value $page -Encoding UTF8 -NoNewline
  Write-Host "Import added to page.tsx."
} else {
  Write-Host "Import already present in page.tsx, nothing changed there."
}

# ---------------------------------------------------------------
# 2. New CSS file: top-align hero row + group badges + fix mobile stacking
#    Pure additive overrides, higher specificity than globals.css.
#    globals.css itself is not touched.
# ---------------------------------------------------------------
$css = @'
/* hero-redesign.css - top-aligns logo/title/CTA on one line and groups the
   5 badges into "facts" (difficulty/cost/blockchain) + "security" (audit/contract).
   Pure additive overrides via higher-specificity selectors; globals.css untouched. */

.project-hero.project-hero--split {
  align-items: flex-start;
}

.project-hero.project-hero--split .project-hero__icon {
  align-self: flex-start;
  margin-top: 2px;
}

.project-hero.project-hero--split .project-hero__main {
  align-self: flex-start;
  padding-top: 0;
}

.project-hero.project-hero--split .project-hero__cta {
  align-self: flex-start;
  margin-top: 2px;
}

/* Visual split between facts and security checks - the 4th badge (Audit)
   starts the second group. Order is fixed in ProjectBadges.tsx: difficulty,
   cost, chain, audit, contract. Desktop only - looks odd once wrapped. */

@media (min-width: 761px) {
  .project-hero--split .badges-row .badge-item:nth-child(4) {
    margin-left: 8px;
    padding-left: 16px;
    border-left: 1px solid rgba(255, 255, 255, 0.12);
  }
}

/* Real 2-per-row / 1-per-row badge stacking on small screens. The existing
   globals.css rules for this target a ".badge" class that the markup no
   longer uses (it renders "badge-item"), so they currently do nothing. */

@media (max-width: 760px) {
  .project-hero--split .badges-row {
    width: 100%;
    gap: 8px;
  }

  .project-hero--split .badges-row .badge-item {
    flex: 1 1 calc(50% - 8px);
    min-width: 0;
  }
}

@media (max-width: 430px) {
  .project-hero--split .badges-row .badge-item {
    flex-basis: 100%;
  }
}
'@

Set-Content -LiteralPath $cssPath -Value $css -Encoding UTF8

Write-Host ""
Write-Host "Done."
Write-Host "Backup:   $pagePath.bak-35"
Write-Host "New file: $cssPath"
