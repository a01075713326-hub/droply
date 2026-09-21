# apply-hubs-22.ps1
# 1) app\sitemap.ts   : adds /chain/*, /category/* and /airdrops/live (only indexable hubs)
# 2) components\Header.tsx : "Live Airdrops" -> /airdrops/live, BY BLOCKCHAIN -> /chain/<slug>
# Requires add-hubs-21.ps1 to be run first.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\apply-hubs-22.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
$need = @(
  "package.json",
  "app\sitemap.ts",
  "components\Header.tsx",
  "lib\hubs.ts",
  "app\airdrops\live\page.tsx"
)
foreach ($n in $need) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    if (($n -like "lib*") -or ($n -like "app\airdrops*")) { Write-Host "Run add-hubs-21.ps1 first." }
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

# ---- 2. Replacement blocks --------------------------------------------------
$smImport = @'
import { getOverride, isIndexable } from "@/lib/overrides";
import { getChainHubs, getCategoryHubs, getLiveProjects, HUB_MIN } from "@/lib/hubs";
'@

$smHelper = @'
function latestFor(items: any[]): Date | undefined {
  const times = items
    .map((p) => lastModifiedFor(p))
    .filter((d): d is Date => d !== undefined)
    .map((d) => d.getTime());
  return times.length ? new Date(Math.max(...times)) : undefined;
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
'@

$smReturn = @'
const chainHubs = getChainHubs(projects);
  const categoryHubs = getCategoryHubs(projects);
  const liveProjects = getLiveProjects(projects);

  // Hub pages: only those with enough projects (same rule as the pages themselves).
  const hubRoutes: MetadataRoute.Sitemap = [
    ...chainHubs.map((h) => ({
      url: `${BASE}/chain/${h.slug}`,
      lastModified: latestFor(h.items),
    })),
    ...categoryHubs.map((h) => ({
      url: `${BASE}/category/${h.slug}`,
      lastModified: latestFor(h.items),
    })),
    ...(liveProjects.length >= HUB_MIN
      ? [{ url: `${BASE}/airdrops/live`, lastModified: latestFor(liveProjects) }]
      : []),
  ];

  return [...staticRoutes, ...hubRoutes, ...legalRoutes, ...projectRoutes];
'@

$hdImport = @'
import { getProjects } from "@/lib/projects";
import type { Project } from "@/data/projects";
import { getChainHubs, slugify, type Hub } from "@/lib/hubs";
'@

$hdMenu = @'
.filter((x) => x.name && x.slug);

  // BY BLOCKCHAIN menu: preferred chains first, only those that have a hub page.
  const PREFERRED_CHAINS = ["Base", "Solana", "Ethereum", "Arbitrum", "Hyperliquid", "Aptos", "Sui", "TON", "ZKsync", "Blast"];
  const chainHubs = getChainHubs(all as unknown as Project[]);
  const menuChains = PREFERRED_CHAINS
    .map((name) => chainHubs.find((h) => h.slug === slugify(name)))
    .filter((h): h is Hub => Boolean(h));
  for (const h of chainHubs) {
    if (menuChains.length >= 10) break;
    if (!menuChains.some((m) => m.slug === h.slug)) menuChains.push(h);
  }
'@

$edits = @{}

$edits["app\sitemap.ts"] = @(
  @{ find = 'import { getOverride, isIndexable } from "@/lib/overrides";'; repl = $smImport },
  @{ find = 'export default async function sitemap(): Promise<MetadataRoute.Sitemap> {'; repl = $smHelper },
  @{ find = 'return [...staticRoutes, ...legalRoutes, ...projectRoutes];'; repl = $smReturn }
)

$edits["components\Header.tsx"] = @(
  @{ find = 'import { getProjects } from "@/lib/projects";'; repl = $hdImport },
  @{ find = '.filter((x) => x.name && x.slug);'; repl = $hdMenu },
  @{ find = '<Link href="/airdrops?status=live">'; repl = '<Link href="/airdrops/live">' },
  @{ find = '{["Base","Solana","Ethereum","Arbitrum","Hyperliquid","Aptos","Sui","TON","ZKsync","Blast"].map((chain) =>'; repl = '{menuChains.map((hub) =>' },
  @{ find = '<Link href={`/airdrops?chain=${encodeURIComponent(chain)}`} key={chain}>{chain}</Link>'; repl = '<Link href={`/chain/${hub.slug}`} key={hub.slug}>{hub.name}</Link>' }
)

# ---- 3. Phase 1: verify every fragment, build new texts in memory ----------
$newTexts = @{}
$failed = $false
foreach ($rel in $edits.Keys) {
  $full = [System.IO.Path]::Combine($root, $rel)
  $text = [System.IO.File]::ReadAllText($full)

  if ($text.Contains("@/lib/hubs")) {
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

# ---- 4. Phase 2: backup and write ------------------------------------------
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null

foreach ($rel in $newTexts.Keys) {
  $full = [System.IO.Path]::Combine($root, $rel)
  $name = ($rel -replace '[\\/\[\]]', '_')
  Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
  [System.IO.File]::WriteAllText($full, $newTexts[$rel], $utf8)
  Write-Host "PATCHED $rel"
}

Write-Host ""
Write-Host "DONE. Restart 'npm run dev' and check /sitemap.xml and the Airdrops menu."
