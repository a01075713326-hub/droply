# add-badge-icon-30.ps1
# components\ProjectBadges.tsx : chain logo in front of the chain name in the "Blockchain" badge.
# Requires add-chain-icons-cards-28.ps1 to be run first.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\add-badge-icon-30.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
$rel = "components\ProjectBadges.tsx"
foreach ($n in @("package.json", $rel, "components\ChainIcon.tsx")) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    if ($n -like "components\ChainIcon*") { Write-Host "Run add-chain-icons-cards-28.ps1 first." }
    else { Write-Host "Run this script from the project root." }
    exit 1
  }
}

function Count-Of($text, $needle) {
  $c = 0
  $i = 0
  while (($i = $text.IndexOf($needle, $i, [System.StringComparison]::Ordinal)) -ge 0) {
    $c++
    $i += $needle.Length
  }
  return $c
}

$full = [System.IO.Path]::Combine($root, $rel)
$text = [System.IO.File]::ReadAllText($full)

if ($text.Contains("ChainIcon")) {
  Write-Host "SKIP $rel (already patched)"
  exit 0
}

$nl = "`n"
if ($text.Contains("`r`n")) { $nl = "`r`n" }

# ---- 2. Fragments ----------------------------------------------------------
$e1Old = 'export type BadgeState = "ok" | "warn" | "unknown";'
$e1New = @'
import type { ReactNode } from "react";
import ChainIcon from "@/components/ChainIcon";

export type BadgeState = "ok" | "warn" | "unknown";
'@

$e2Old = 'tone: Tone;'
$e2New = @'
tone: Tone;
  icon?: ReactNode;
'@

$e3Old = 'value: chain,'
$e3New = @'
value: chain,
      icon: <ChainIcon chain={chain} size={16} inline />,
'@

$e4Old = '<span className="badge-item-value">{b.value}</span>'
$e4New = '<span className="badge-item-value">{b.icon}{b.value}</span>'

$edits = @(
  @{ find = $e1Old; repl = $e1New },
  @{ find = $e2Old; repl = $e2New },
  @{ find = $e3Old; repl = $e3New },
  @{ find = $e4Old; repl = $e4New }
)

# ---- 3. Verify everything first --------------------------------------------
$failed = $false
foreach ($e in $edits) {
  $cnt = Count-Of $text $e.find
  if ($cnt -ne 1) {
    Write-Host ("NOT FOUND (" + $cnt + " matches) in " + $rel + ": " + $e.find)
    $failed = $true
  }
}
if ($failed) {
  Write-Host ""
  Write-Host "Nothing was written. Send me the NOT FOUND line(s) above."
  exit 1
}

foreach ($e in $edits) {
  $r = $e.repl -replace "`r?`n", $nl
  $text = $text.Replace($e.find, $r)
}

# ---- 4. Backup and write ---------------------------------------------------
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null
$name = ($rel -replace '[\\/\[\]]', '_')
Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
[System.IO.File]::WriteAllText($full, $text, $utf8)
Write-Host "PATCHED $rel"
Write-Host ""
Write-Host "DONE. Reload a project page (for example /project/baibai)."
