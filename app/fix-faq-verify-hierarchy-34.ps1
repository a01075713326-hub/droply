$ErrorActionPreference = "Stop"

$root = "C:\Users\Sasa\Desktop\zip"
Set-Location $root

$pagePath = ".\app\project\[slug]\page.tsx"
$vbPath   = ".\components\VerificationBlock.tsx"
$cssPath  = ".\app\project\[slug]\verify-faq-tone.css"

if (-not (Test-Path -LiteralPath $pagePath)) { Write-Host "STOP: page.tsx not found at $pagePath"; exit 1 }
if (-not (Test-Path -LiteralPath $vbPath))   { Write-Host "STOP: VerificationBlock.tsx not found at $vbPath"; exit 1 }

Copy-Item -LiteralPath $pagePath -Destination "$pagePath.bak-34" -Force
Copy-Item -LiteralPath $vbPath   -Destination "$vbPath.bak-34"   -Force

# ---------------------------------------------------------------
# 1. page.tsx: open the first FAQ item by default
# ---------------------------------------------------------------
$page = Get-Content -LiteralPath $pagePath -Raw -Encoding UTF8

$mapOld = "{faqItems.map((f) => ("
$mapNew = "{faqItems.map((f, i) => ("
$detailsOld = '<details key={f.q} className="faq-item">'
$detailsNew = '<details key={f.q} className="faq-item" open={i === 0}>'

$mapCount = ([regex]::Matches($page, [regex]::Escape($mapOld))).Count
$detailsCount = ([regex]::Matches($page, [regex]::Escape($detailsOld))).Count

if ($mapCount -ne 1 -or $detailsCount -ne 1) {
  Write-Host "STOP: expected exactly one FAQ map/details match, found map=$mapCount details=$detailsCount. Nothing changed."
  exit 1
}

$page = $page.Replace($mapOld, $mapNew).Replace($detailsOld, $detailsNew)

# Insert the CSS import, respecting a possible "use client" directive on line 1
$importLine = 'import "./verify-faq-tone.css";'
if ($page -notmatch [regex]::Escape($importLine)) {
  $lines = $page -split "`r?`n", 2
  if ($lines[0] -match '^\s*["'']use (client|server)["'']\s*;?\s*$') {
    $page = $lines[0] + "`r`n" + $importLine + "`r`n" + $lines[1]
  } else {
    $page = $importLine + "`r`n" + $page
  }
}

Set-Content -LiteralPath $pagePath -Value $page -Encoding UTF8 -NoNewline

# ---------------------------------------------------------------
# 2. VerificationBlock.tsx: tag CONTRACT as danger, AUDIT as warning
# ---------------------------------------------------------------
$vb = Get-Content -LiteralPath $vbPath -Raw -Encoding UTF8

$sectionOld = @'
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
'@

$sectionNew = @'
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
'@

if (($vb -split [regex]::Escape($sectionOld)).Count -ne 2) {
  Write-Host "STOP: Section() function body not found exactly once in VerificationBlock.tsx. Nothing changed."
  exit 1
}
$vb = $vb.Replace($sectionOld, $sectionNew)

$contractOld = '<Section title="CONTRACT">'
$auditOld    = '<Section title="AUDIT">'

if ((($vb -split [regex]::Escape($contractOld)).Count -ne 2) -or (($vb -split [regex]::Escape($auditOld)).Count -ne 2)) {
  Write-Host "STOP: CONTRACT/AUDIT Section tags not found exactly once each. Nothing changed."
  exit 1
}

$vb = $vb.Replace($contractOld, '<Section title="CONTRACT" tone="danger">')
$vb = $vb.Replace($auditOld,    '<Section title="AUDIT" tone="warning">')

Set-Content -LiteralPath $vbPath -Value $vb -Encoding UTF8 -NoNewline

# ---------------------------------------------------------------
# 3. New CSS file, imported from page.tsx. globals.css is not touched.
# ---------------------------------------------------------------
$css = @'
/* verify-faq-tone.css - hierarchy pass on FAQ + Verification blocks.
   Loaded via import in page.tsx. Does not touch globals.css. */

.faq-card__title {
  font-weight: 700;
  color: #ffffff;
}

.faq-item summary {
  color: rgba(255, 255, 255, 0.65);
}

.faq-item[open] summary {
  color: #ffffff;
}

.faq-item summary::after {
  color: rgba(255, 255, 255, 0.4);
}

.faq-item[open] summary::after {
  color: #b9a3ff;
}

.section-kicker {
  font-size: 11px;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: rgba(255, 255, 255, 0.4);
}

/* Only rows whose status is "not_found" get the tone color -
   confirmed / unverified rows in the same section are untouched. */

.verify-section--danger .verify-icon.not_found {
  border-color: rgba(255, 92, 110, 0.35);
  background: rgba(255, 92, 110, 0.12);
  color: #ff8a96;
}

.verify-section--danger .verify-icon.not_found ~ .verify-row-body .verify-row-title {
  color: #ff8a96;
}

.verify-section--warning .verify-icon.not_found {
  border-color: rgba(247, 195, 88, 0.3);
  background: rgba(247, 195, 88, 0.12);
  color: #f7c358;
}

.verify-section--warning .verify-icon.not_found ~ .verify-row-body .verify-row-title {
  color: #f7c358;
}
'@

Set-Content -LiteralPath $cssPath -Value $css -Encoding UTF8

Write-Host ""
Write-Host "Done."
Write-Host "Backups:  $pagePath.bak-34"
Write-Host "          $vbPath.bak-34"
Write-Host "New file: $cssPath"
