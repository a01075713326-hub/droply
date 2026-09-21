$ErrorActionPreference = "Stop"

$root = "C:\Users\Sasa\Desktop\zip"
Set-Location $root

$pagePath = ".\app\project\[slug]\page.tsx"
$cssPath  = ".\app\project\[slug]\cryptorank-overview-v2.css"

if (-not (Test-Path -LiteralPath $pagePath)) { Write-Host "STOP: page.tsx not found at $pagePath"; exit 1 }

# ---------------------------------------------------------------
# 1. Import the new CSS from page.tsx (respects "use client")
# ---------------------------------------------------------------
$page = Get-Content -LiteralPath $pagePath -Raw -Encoding UTF8
$importLine = 'import "./cryptorank-overview-v2.css";'

if ($page -notmatch [regex]::Escape($importLine)) {
  $lines = $page -split "`r?`n", 2
  if ($lines[0] -match '^\s*["'']use (client|server)["'']\s*;?\s*$') {
    $page = $lines[0] + "`r`n" + $importLine + "`r`n" + $lines[1]
  } else {
    $page = $importLine + "`r`n" + $page
  }
  Copy-Item -LiteralPath $pagePath -Destination "$pagePath.bak-37" -Force
  Set-Content -LiteralPath $pagePath -Value $page -Encoding UTF8 -NoNewline
  Write-Host "Import added to page.tsx. Backup: $pagePath.bak-37"
} else {
  Write-Host "Import already present in page.tsx, nothing changed there."
}

# ---------------------------------------------------------------
# 2. New CSS file - pure CSS restructure of the CryptoRank Overview
#    block. No .tsx is touched. Falls back to the original stacked
#    layout automatically when there is no topbar (:has() guard).
# ---------------------------------------------------------------
$css = @'
/* cryptorank-overview-v2.css - Overview redesign, variant 2 ("spec sheet"):
   Moni score + status flags become a left sidebar, all fact tiles become
   a plain row list on the right. Pure CSS, CryptoRankDetails.tsx untouched.
   Falls back to the original stacked layout when there is no topbar. */

@media (min-width: 561px) {
  .crx-card:has(> .crx-topbar) {
    grid-template-columns: 150px 1fr;
    column-gap: 20px;
  }

  .crx-card:has(> .crx-topbar) > .crx-head {
    grid-column: 1 / -1;
  }

  .crx-card:has(> .crx-topbar) > .crx-topbar {
    grid-column: 1;
    grid-row: 2;
    flex-direction: column;
    align-items: center;
    justify-content: flex-start;
    gap: 10px;
    padding-right: 16px;
    border-right: 1px solid var(--crx-border);
  }

  .crx-card:has(> .crx-topbar) > .crx-tiles {
    grid-column: 2;
    grid-row: 2;
  }

  .crx-card:has(> .crx-topbar) > .crx-group {
    grid-column: 1 / -1;
  }
}

/* Tiles: boxes -> plain row list with a hairline divider */

.crx-tiles {
  display: flex;
  flex-direction: column;
  gap: 0;
}

.crx-tile {
  padding: 9px 0;
  border-bottom: 1px solid var(--crx-border);
  background: none;
  border-radius: 0;
}

.crx-tile:last-child {
  border-bottom: none;
}

.crx-tile__icon {
  display: none;
}

.crx-tile__text {
  display: flex;
  flex-direction: row;
  justify-content: space-between;
  align-items: baseline;
  width: 100%;
  gap: 10px;
}

.crx-tile__label {
  color: var(--crx-muted);
  font-size: 13px;
}

.crx-tile__value {
  font-size: 14px;
  font-weight: 500;
}
'@

Set-Content -LiteralPath $cssPath -Value $css -Encoding UTF8

Write-Host ""
Write-Host "Done."
Write-Host "New file: $cssPath"
