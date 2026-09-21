$ErrorActionPreference = "Stop"

$root = "C:\Users\Sasa\Desktop\zip"
Set-Location $root

$pbPath   = ".\components\ProjectBadges.tsx"
$pagePath = ".\app\project\[slug]\page.tsx"
$cssPath  = ".\app\project\[slug]\badge-caution.css"

if (-not (Test-Path -LiteralPath $pbPath))   { Write-Host "STOP: ProjectBadges.tsx not found at $pbPath"; exit 1 }
if (-not (Test-Path -LiteralPath $pagePath)) { Write-Host "STOP: page.tsx not found at $pagePath"; exit 1 }

Copy-Item -LiteralPath $pbPath -Destination "$pbPath.bak-36" -Force

# ---------------------------------------------------------------
# 1. ProjectBadges.tsx: give "no audit" its own amber tone,
#    separate from the red "no contract" tone.
# ---------------------------------------------------------------
$pb = Get-Content -LiteralPath $pbPath -Raw -Encoding UTF8

$typeOld = 'type Tone = "neutral" | "ok" | "warn";'
$typeNew = 'type Tone = "neutral" | "ok" | "warn" | "caution";'

$auditOld = @'
    audit === "ok"
      ? { label: "Security", value: "Audited", tone: "ok" as Tone }
      : {
          label: audit === "warn" ? "Warning" : "Audit",
          value: audit === "warn" ? "No audit" : "Not checked",
          tone: audit === "warn" ? ("warn" as Tone) : ("neutral" as Tone),
        },
'@

$auditNew = @'
    audit === "ok"
      ? { label: "Security", value: "Audited", tone: "ok" as Tone }
      : {
          label: audit === "warn" ? "Warning" : "Audit",
          value: audit === "warn" ? "No audit" : "Not checked",
          tone: audit === "warn" ? ("caution" as Tone) : ("neutral" as Tone),
        },
'@

if (($pb -split [regex]::Escape($typeOld)).Count -ne 2) {
  Write-Host "STOP: Tone type declaration not found exactly once. Nothing changed."
  exit 1
}
if (($pb -split [regex]::Escape($auditOld)).Count -ne 2) {
  Write-Host "STOP: audit badge block not found exactly once (as expected). Nothing changed."
  exit 1
}

$pb = $pb.Replace($typeOld, $typeNew)
$pb = $pb.Replace($auditOld, $auditNew)

Set-Content -LiteralPath $pbPath -Value $pb -Encoding UTF8 -NoNewline

# ---------------------------------------------------------------
# 2. Import the CSS for the new tone from page.tsx
# ---------------------------------------------------------------
$page = Get-Content -LiteralPath $pagePath -Raw -Encoding UTF8
$importLine = 'import "./badge-caution.css";'

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
# 3. New CSS: amber "caution" tone, same visual language as
#    .verify-risk.medium / .verify-icon.unverified elsewhere on the page.
# ---------------------------------------------------------------
$css = @'
/* badge-caution.css - amber tone for "no audit" in the hero badge row,
   kept visually distinct from the red "no contract" tone. */

.badge-item--caution {
  border-color: rgba(247, 195, 88, 0.3);
  background: rgba(247, 195, 88, 0.08);
}

.badge-item--caution .badge-item-label,
.badge-item--caution .badge-item-value {
  color: #f7c358;
}
'@

Set-Content -LiteralPath $cssPath -Value $css -Encoding UTF8

Write-Host ""
Write-Host "Done."
Write-Host "Backup:   $pbPath.bak-36"
Write-Host "New file: $cssPath"
