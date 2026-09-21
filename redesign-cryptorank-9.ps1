# redesign-cryptorank-9.ps1 (part 1: verification text summary)
# Run from the project root: .\redesign-cryptorank-9.ps1
# What it does:
#   1. Adds a plain-language summary above the links list, built from check results
#   2. Wraps the scoring rules table in <details> (closed for Unknown risk, open otherwise)
#   3. Adds an "automated assessment, not financial advice" note
#   4. Appends styles to the CSS file that already contains .verify-rules
# Backup: components\VerificationBlock.tsx.bak-redesign9
# NOTE: this file is ASCII-only on purpose, so encoding cannot break it.

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

$vb = '.\components\VerificationBlock.tsx'
if (-not (Test-Path -LiteralPath $vb)) {
  Write-Host "File $vb not found. Run this from the project root." -ForegroundColor Red
  exit 1
}

$path = (Resolve-Path -LiteralPath $vb).Path
$src = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

if ($src.Contains('buildSummary')) {
  Write-Host 'Already applied (buildSummary found). Nothing to do.' -ForegroundColor Green
  exit 0
}

# ---------- 1. Helpers ----------
$helper = @'
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
'@

$s = Patch $src 'const LINK_TITLE: Record<string, string> = {' ($helper + "`r`n`r`n" + 'const LINK_TITLE: Record<string, string> = {') 'insert buildSummary'
if ($null -eq $s) { exit 1 }

# ---------- 2. summary variable ----------
$s = Patch $s '  const stale = isStale(checkedAt);' ('  const stale = isStale(checkedAt);' + "`r`n" + '  const summary = buildSummary(verification);') 'summary variable'
if ($null -eq $s) { exit 1 }

# ---------- 3. Summary above the links list ----------
$s = Patch $s '      <Section title="OFFICIAL LINKS">' ('      <p className="verify-summary">{summary}</p>' + "`r`n`r`n" + '      <Section title="OFFICIAL LINKS">') 'render summary'
if ($null -eq $s) { exit 1 }

# ---------- 4. Rules table in <details> + disclaimer ----------
$open = @'
        <details className="verify-rules-details" open={risk.level !== "Unknown"}>
          <summary>Show all scoring rules</summary>
          <ul className="verify-rules">
'@
$s = Patch $s '        <ul className="verify-rules">' $open.TrimEnd() 'open details'
if ($null -eq $s) { exit 1 }

$close = @'
        </ul>
        </details>
        <p className="verify-disclaimer">
          Automated assessment based on public data. It is not financial advice. Always check the
          official sources before connecting a wallet.
        </p>
'@
$s = Patch $s '        </ul>' $close.TrimEnd() 'close details'
if ($null -eq $s) { exit 1 }

# ---------- Write ----------
Copy-Item -LiteralPath $path "${path}.bak-redesign9"
[System.IO.File]::WriteAllText($path, $s, $utf8)
Write-Host 'VerificationBlock.tsx updated.' -ForegroundColor Green

# ---------- 5. Styles ----------
$css = Get-ChildItem -Path .\app, .\components, .\styles -Recurse -File -Include *.css -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch 'node_modules|\\\.next\\' } |
  Where-Object { Select-String -LiteralPath $_.FullName -Pattern 'verify-rules' -Quiet } |
  Select-Object -First 1

if (-not $css) {
  Write-Host 'CSS file with .verify-rules not found. Add these styles manually:' -ForegroundColor Yellow
  Write-Host '.verify-summary{margin:12px 0 4px;font-size:14px;line-height:1.55}'
  Write-Host '.verify-disclaimer{margin-top:12px;font-size:12px;opacity:.6}'
  Write-Host '.verify-rules-details>summary{cursor:pointer;font-size:12px;opacity:.7;margin:6px 0}'
  exit 0
}

$cssText = [System.IO.File]::ReadAllText($css.FullName, [System.Text.Encoding]::UTF8)
if (-not $cssText.Contains('.verify-summary')) {
  Copy-Item -LiteralPath $css.FullName "$($css.FullName).bak-redesign9"
  $add = @'

/* redesign-9: verification summary */
.verify-summary {
  margin: 14px 0 6px;
  font-size: 14px;
  line-height: 1.6;
  opacity: 0.9;
}
.verify-disclaimer {
  margin-top: 14px;
  font-size: 12px;
  line-height: 1.5;
  opacity: 0.6;
}
.verify-rules-details > summary {
  cursor: pointer;
  font-size: 12px;
  opacity: 0.7;
  margin: 8px 0;
}
'@
  [System.IO.File]::WriteAllText($css.FullName, $cssText + $add, $utf8)
  Write-Host "Styles added to $($css.FullName)" -ForegroundColor Green
}

Write-Host 'Done. Run npm run dev and open /project/fables (or any other project).' -ForegroundColor Green
