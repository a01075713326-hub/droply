# add-chain-icons-25.ps1
# New files:  lib\chain-icons.ts, components\ChainIcon.tsx, public\chains\ (folder for logo files)
# Patched:    app\chain\[chain]\page.tsx, app\airdrops\live\page.tsx
# Icon = file public\chains\<slug>.svg|png|webp if it exists, otherwise a colored badge with the first letter.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\add-chain-icons-25.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
$need = @(
  "package.json",
  "lib\hubs.ts",
  "app\chain\[chain]\page.tsx",
  "app\airdrops\live\page.tsx"
)
foreach ($n in $need) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    Write-Host "Run this script from the project root (after add-hubs-21.ps1)."
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

# ---- 2. New files -----------------------------------------------------------
$iconLib = @'
import fs from "node:fs";
import path from "node:path";

const EXTS = ["svg", "png", "webp"];

/**
 * Own logo file for a chain: public/chains/<slug>.svg | .png | .webp
 * Server-side only (uses fs).
 */
export function chainIconSrc(slug: string): string | null {
  for (const ext of EXTS) {
    const file = path.join(process.cwd(), "public", "chains", `${slug}.${ext}`);
    if (fs.existsSync(file)) return `/chains/${slug}.${ext}`;
  }
  return null;
}

// [background, text] of the letter badge that is shown while there is no logo file.
const BRAND: Record<string, [string, string]> = {
  solana: ["#9945FF", "#FFFFFF"],
  base: ["#0052FF", "#FFFFFF"],
  ethereum: ["#627EEA", "#FFFFFF"],
  "bnb-chain": ["#F3BA2F", "#1A1A1A"],
  arbitrum: ["#28A0F0", "#FFFFFF"],
  hyperliquid: ["#97FCE4", "#0B2B26"],
  polygon: ["#8247E5", "#FFFFFF"],
  robinhood: ["#00C805", "#04210A"],
};

export function chainColors(slug: string): [string, string] {
  const known = BRAND[slug];
  if (known) return known;
  let hue = 0;
  for (let i = 0; i < slug.length; i++) {
    hue = (hue * 31 + slug.charCodeAt(i)) % 360;
  }
  return [`hsl(${hue}, 55%, 42%)`, "#FFFFFF"];
}
'@

$iconComponent = @'
import type { CSSProperties } from "react";
import { chainIconSrc, chainColors } from "@/lib/chain-icons";

export default function ChainIcon({
  slug,
  name,
  size = 16,
}: {
  slug: string;
  name: string;
  size?: number;
}) {
  const src = chainIconSrc(slug);
  const base: CSSProperties = {
    width: size,
    height: size,
    borderRadius: "50%",
    flex: "none",
  };

  if (src) {
    return (
      <img
        src={src}
        alt=""
        width={size}
        height={size}
        loading="lazy"
        decoding="async"
        style={{ ...base, objectFit: "contain" }}
      />
    );
  }

  const [bg, fg] = chainColors(slug);
  return (
    <span
      aria-hidden="true"
      style={{
        ...base,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        background: bg,
        color: fg,
        fontSize: Math.max(8, Math.round(size * 0.58)),
        fontWeight: 700,
        lineHeight: 1,
      }}
    >
      {name.trim().charAt(0).toUpperCase()}
    </span>
  );
}
'@

# ---- 3. Edits of existing files --------------------------------------------
$importOld = 'import ProjectCards from "@/components/ProjectCards";'
$importNew = @'
import ProjectCards from "@/components/ProjectCards";
import ChainIcon from "@/components/ChainIcon";
'@

$chipOld = '{h.name} ({h.items.length})'
$chipNew = '<span style={{ display: "inline-flex", alignItems: "center", gap: 6 }}><ChainIcon slug={h.slug} name={h.name} size={16} />{h.name} ({h.items.length})</span>'

$h1Old = '<h1>{hub.name} Airdrops</h1>'
$h1New = '<h1 style={{ display: "flex", alignItems: "center", gap: 12 }}><ChainIcon slug={hub.slug} name={hub.name} size={36} />{hub.name} Airdrops</h1>'

$edits = @{}
$edits["app\chain\[chain]\page.tsx"] = @(
  @{ find = $importOld; repl = $importNew },
  @{ find = $h1Old; repl = $h1New },
  @{ find = $chipOld; repl = $chipNew }
)
$edits["app\airdrops\live\page.tsx"] = @(
  @{ find = $importOld; repl = $importNew },
  @{ find = $chipOld; repl = $chipNew }
)

# ---- 4. Phase 1: verify fragments, build new texts in memory ---------------
$newTexts = @{}
$failed = $false
foreach ($rel in $edits.Keys) {
  $full = [System.IO.Path]::Combine($root, $rel)
  $text = [System.IO.File]::ReadAllText($full)

  if ($text.Contains("ChainIcon")) {
    Write-Host "SKIP $rel (already patched)"
    continue
  }

  $nl = "`n"
  if ($text.Contains("`r`n")) { $nl = "`r`n" }

  foreach ($e in $edits[$rel]) {
    $cnt = Count-Of $text $e.find
    if ($cnt -ne 1) {
      Write-Host ("NOT FOUND (" + $cnt + " matches) in " + $rel + ": " + $e.find)
      $failed = $true
    }
  }
  if ($failed) { continue }

  foreach ($e in $edits[$rel]) {
    $r = $e.repl -replace "`r?`n", $nl
    $text = $text.Replace($e.find, $r)
  }
  $newTexts[$rel] = $text
}

if ($failed) {
  Write-Host ""
  Write-Host "Nothing was written. Send me the NOT FOUND line(s) above."
  exit 1
}

# ---- 5. Phase 2: backup and write ------------------------------------------
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null

function Backup-If-Exists($rel) {
  $full = [System.IO.Path]::Combine($root, $rel)
  if (Test-Path -LiteralPath $full) {
    $name = ($rel -replace '[\\/\[\]]', '_')
    Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
  }
}

# new files
$newFiles = @{}
$newFiles["lib\chain-icons.ts"] = $iconLib
$newFiles["components\ChainIcon.tsx"] = $iconComponent
foreach ($rel in $newFiles.Keys) {
  $full = [System.IO.Path]::Combine($root, $rel)
  Backup-If-Exists $rel
  [System.IO.File]::WriteAllText($full, $newFiles[$rel], $utf8)
  Write-Host "WROTE $rel"
}

# patched files
foreach ($rel in $newTexts.Keys) {
  $full = [System.IO.Path]::Combine($root, $rel)
  Backup-If-Exists $rel
  [System.IO.File]::WriteAllText($full, $newTexts[$rel], $utf8)
  Write-Host "PATCHED $rel"
}

# folder for logo files
[System.IO.Directory]::CreateDirectory([System.IO.Path]::Combine($root, "public\chains")) | Out-Null
Write-Host "FOLDER public\chains (put logo files here, e.g. solana.svg)"

Write-Host ""
Write-Host "DONE. Restart 'npm run dev' and open /airdrops/live or /chain/solana"
