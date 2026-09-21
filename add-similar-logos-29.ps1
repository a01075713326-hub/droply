# add-similar-logos-29.ps1
# app\project\[slug]\page.tsx : "Similar airdrops" shows the project logo before the name
#                               and the chain logo before the chain name.
# New file: components\ProjectLogo.tsx (client component: shows initials if the logo fails to load)
# Requires add-chain-icons-cards-28.ps1 to be run first.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\add-similar-logos-29.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
$pageRel = "app\project\[slug]\page.tsx"
foreach ($n in @("package.json", $pageRel, "components\ChainIcon.tsx", "lib\chain-slug.ts")) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    if (($n -like "components\ChainIcon*") -or ($n -like "lib\chain-slug*")) { Write-Host "Run add-chain-icons-cards-28.ps1 first." }
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

# ---- 2. New component -------------------------------------------------------
$projectLogo = @'
"use client";

import { useState, type CSSProperties } from "react";

function letters(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/** Small project logo. Falls back to initials when there is no logo or it fails to load. */
export default function ProjectLogo({
  src,
  name,
  size = 22,
}: {
  src?: string;
  name: string;
  size?: number;
}) {
  const [failed, setFailed] = useState(false);
  const box: CSSProperties = {
    width: size,
    height: size,
    borderRadius: 6,
    flex: "none",
  };

  if (src && !failed) {
    return (
      <img
        src={src}
        alt=""
        width={size}
        height={size}
        loading="lazy"
        decoding="async"
        onError={() => setFailed(true)}
        style={{ ...box, objectFit: "cover" }}
      />
    );
  }

  return (
    <span
      aria-hidden="true"
      style={{
        ...box,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        background: "rgba(255, 255, 255, 0.12)",
        fontSize: Math.max(8, Math.round(size * 0.42)),
        fontWeight: 700,
        lineHeight: 1,
      }}
    >
      {letters(name)}
    </span>
  );
}
'@

# ---- 3. page.tsx edits (verify first) --------------------------------------
$pageFull = [System.IO.Path]::Combine($root, $pageRel)
$text = [System.IO.File]::ReadAllText($pageFull)

if ($text.Contains("ProjectLogo")) {
  Write-Host "SKIP $pageRel (already patched)"
  exit 0
}

$nl = "`n"
if ($text.Contains("`r`n")) { $nl = "`r`n" }

$importOld = 'import CryptoRankTasks from "@/components/CryptoRankTasks";'
$importNew = @'
import CryptoRankTasks from "@/components/CryptoRankTasks";
import ChainIcon from "@/components/ChainIcon";
import ProjectLogo from "@/components/ProjectLogo";
'@

$nameOld = '<span className="related-item__name">{o.name}</span>'
$nameNew = '<span className="related-item__name" style={{ display: "inline-flex", alignItems: "center", gap: 8 }}><ProjectLogo src={o.logo} name={o.name} size={22} />{o.name}</span>'

$chainOld = '{o.chain ? ` \u00b7 ${o.chain}` : ""}'
$chainNew = '{o.chain ? <>{" \u00b7 "}<ChainIcon chain={o.chain} size={14} inline />{o.chain}</> : null}'

$edits = @(
  @{ find = $importOld; repl = $importNew },
  @{ find = $nameOld; repl = $nameNew },
  @{ find = $chainOld; repl = $chainNew }
)

$failed = $false
foreach ($e in $edits) {
  $cnt = Count-Of $text $e.find
  if ($cnt -ne 1) {
    Write-Host ("NOT FOUND (" + $cnt + " matches) in " + $pageRel + ": " + $e.find)
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

$logoFull = [System.IO.Path]::Combine($root, "components\ProjectLogo.tsx")
if (Test-Path -LiteralPath $logoFull) {
  Copy-Item -LiteralPath $logoFull -Destination ([System.IO.Path]::Combine($bk, ("components_ProjectLogo.tsx." + $stamp + ".bak")))
}
[System.IO.File]::WriteAllText($logoFull, $projectLogo, $utf8)
Write-Host "WROTE components\ProjectLogo.tsx"

$pname = ($pageRel -replace '[\\/\[\]]', '_')
Copy-Item -LiteralPath $pageFull -Destination ([System.IO.Path]::Combine($bk, ($pname + "." + $stamp + ".bak")))
[System.IO.File]::WriteAllText($pageFull, $text, $utf8)
Write-Host "PATCHED $pageRel"

Write-Host ""
Write-Host "DONE. Reload any project page and look at the Similar airdrops block."
