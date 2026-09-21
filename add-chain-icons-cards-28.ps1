# add-chain-icons-cards-28.ps1
# 1) Makes ChainIcon usable everywhere (also in client components like ProjectCards):
#    it now loads /chain-icon/<slug>, a small route that serves the logo file from public\chains
#    or a colored letter badge when there is no file.
# 2) Adds the chain logo next to the chain name on project cards (components\ProjectCards.tsx).
# New files:  lib\chain-slug.ts, app\chain-icon\[slug]\route.ts
# Rewritten:  components\ChainIcon.tsx (backup is made)
# Patched:    components\ProjectCards.tsx
# Requires add-chain-icons-25.ps1 to be run first.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\add-chain-icons-cards-28.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
foreach ($n in @("package.json", "lib\chain-icons.ts", "components\ChainIcon.tsx", "components\ProjectCards.tsx")) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    if (($n -like "lib\chain-icons*") -or ($n -like "components\ChainIcon*")) { Write-Host "Run add-chain-icons-25.ps1 first." }
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

# ---- 2. New / rewritten files ----------------------------------------------
$chainSlugLib = @'
// Pure helper (safe to import from client components).
const SKIP = new Set([
  "multiple",
  "other",
  "ownchain",
  "unknown",
  "tba",
  "tbd",
  "n/a",
  "none",
]);

/** "Robinhood Ecosystem" -> "robinhood". Returns "" for values that are not a real chain. */
export function chainSlug(raw: string | null | undefined): string {
  const name = (raw || "").trim().replace(/\s+ecosystem$/i, "").trim();
  if (!name || name.includes(",")) return "";
  if (SKIP.has(name.toLowerCase())) return "";
  return name
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}
'@

$iconRoute = @'
import fs from "node:fs";
import path from "node:path";
import { chainIconSrc, chainColors } from "@/lib/chain-icons";

export const dynamic = "force-dynamic";

const TYPES: Record<string, string> = {
  svg: "image/svg+xml",
  png: "image/png",
  jpg: "image/jpeg",
  webp: "image/webp",
};

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug } = await params;
  if (!/^[a-z0-9-]{1,40}$/.test(slug)) {
    return new Response("Not found", { status: 404 });
  }

  // 1) logo file from public/chains
  const src = chainIconSrc(slug);
  if (src) {
    const ext = src.split(".").pop() || "png";
    try {
      const data = fs.readFileSync(path.join(process.cwd(), "public", src));
      return new Response(new Uint8Array(data), {
        headers: {
          "Content-Type": TYPES[ext] || "application/octet-stream",
          "Cache-Control": "public, max-age=3600",
        },
      });
    } catch {
      // fall through to the letter badge
    }
  }

  // 2) letter badge
  const [bg, fg] = chainColors(slug);
  const letter = slug.charAt(0).toUpperCase();
  const svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    `<circle cx="16" cy="16" r="16" fill="${bg}"/>` +
    `<text x="16" y="16" text-anchor="middle" dominant-baseline="central" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="${fg}">${letter}</text>` +
    "</svg>";
  return new Response(svg, {
    headers: {
      "Content-Type": "image/svg+xml",
      "Cache-Control": "public, max-age=3600",
    },
  });
}
'@

$iconComponent = @'
import type { CSSProperties } from "react";
import { chainSlug } from "@/lib/chain-slug";

/**
 * Chain logo. Works in server and client components.
 * Pass either `slug` (hub slug) or the raw chain name via `chain` / `name`.
 * Renders nothing for values that are not a real chain (Multiple, Other, ...).
 */
export default function ChainIcon({
  slug,
  name,
  chain,
  size = 16,
  inline = false,
}: {
  slug?: string;
  name?: string;
  chain?: string;
  size?: number;
  inline?: boolean;
}) {
  const s = slug || chainSlug(chain ?? name);
  if (!s) return null;

  const style: CSSProperties = {
    width: size,
    height: size,
    borderRadius: "50%",
    flex: "none",
    objectFit: "contain",
  };
  if (inline) {
    style.verticalAlign = "middle";
    style.marginRight = 6;
  }

  return (
    <img
      src={`/chain-icon/${s}`}
      alt=""
      width={size}
      height={size}
      loading="lazy"
      decoding="async"
      style={style}
    />
  );
}
'@

# ---- 3. ProjectCards edits (verify first) ----------------------------------
$cardsRel = "components\ProjectCards.tsx"
$cardsFull = [System.IO.Path]::Combine($root, $cardsRel)
$cardsText = [System.IO.File]::ReadAllText($cardsFull)
$patchCards = $true

if ($cardsText.Contains("ChainIcon")) {
  Write-Host "SKIP $cardsRel (already patched)"
  $patchCards = $false
}

if ($patchCards) {
  $nl = "`n"
  if ($cardsText.Contains("`r`n")) { $nl = "`r`n" }

  $importOld = 'import DeadlineBadge from "@/components/DeadlineBadge";'
  $importNew = @'
import DeadlineBadge from "@/components/DeadlineBadge";
import ChainIcon from "@/components/ChainIcon";
'@
  $smallOld = '<small className="card-chain">'
  $smallNew = '<small className="card-chain"><ChainIcon chain={p.chain} size={14} inline />'

  $cardEdits = @(
    @{ find = $importOld; repl = $importNew },
    @{ find = $smallOld; repl = $smallNew }
  )

  $failed = $false
  foreach ($e in $cardEdits) {
    $cnt = Count-Of $cardsText $e.find
    if ($cnt -ne 1) {
      Write-Host ("NOT FOUND (" + $cnt + " matches) in " + $cardsRel + ": " + $e.find)
      $failed = $true
    }
  }
  if ($failed) {
    Write-Host ""
    Write-Host "Nothing was written. Send me the NOT FOUND line(s) above."
    exit 1
  }
  foreach ($e in $cardEdits) {
    $r = $e.repl -replace "`r?`n", $nl
    $cardsText = $cardsText.Replace($e.find, $r)
  }
}

# ---- 4. Write everything (with backups) ------------------------------------
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null

function Write-File($rel, $content) {
  $full = [System.IO.Path]::Combine($root, $rel)
  [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($full)) | Out-Null
  if (Test-Path -LiteralPath $full) {
    $name = ($rel -replace '[\\/\[\]]', '_')
    Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
  }
  [System.IO.File]::WriteAllText($full, $content, $utf8)
}

Write-File "lib\chain-slug.ts" $chainSlugLib
Write-Host "WROTE lib\chain-slug.ts"
Write-File "app\chain-icon\[slug]\route.ts" $iconRoute
Write-Host "WROTE app\chain-icon\[slug]\route.ts"
Write-File "components\ChainIcon.tsx" $iconComponent
Write-Host "WROTE components\ChainIcon.tsx"
if ($patchCards) {
  Write-File $cardsRel $cardsText
  Write-Host "PATCHED $cardsRel"
}

Write-Host ""
Write-Host "DONE. Restart 'npm run dev', then open /airdrops (cards) and /airdrops/live."
