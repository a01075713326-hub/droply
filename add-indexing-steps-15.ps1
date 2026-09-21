$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$fOver = Join-Path $root "lib\overrides.ts"
$fPage = Join-Path $root "app\project\[slug]\page.tsx"
$fMap  = Join-Path $root "app\sitemap.ts"

foreach ($f in @($fOver, $fPage, $fMap)) {
  if (-not (Test-Path -LiteralPath $f)) { Write-Host ("NOT FOUND " + $f); exit 1 }
}

function Read-Lf($path) {
  return [System.IO.File]::ReadAllText($path, $utf8).Replace("`r`n", "`n")
}

$script:failed = $false

function Rep([string]$text, [string]$old, [string]$new, [string]$label) {
  $count = $text.Split(@($old), [System.StringSplitOptions]::None).Count - 1
  if ($count -ne 1) {
    Write-Host ("NOT FOUND (or not unique, found " + $count + "): " + $label)
    $script:failed = $true
    return $text
  }
  return $text.Replace($old, $new)
}

$over = Read-Lf $fOver
$page = Read-Lf $fPage
$map  = Read-Lf $fMap

if ($over.Contains("isIndexable") -or $page.Contains("isIndexable") -or $map.Contains("isIndexable")) {
  Write-Host "SKIP: isIndexable already present in one of the files, nothing changed"
  exit 0
}

# ---- lib/overrides.ts ----
$stepsField = @'
  notes?: string[];
  /** Your own step-by-step guide. When present it replaces the steps parsed from the source. */
  steps?: string[];
'@
$over = Rep $over '  notes?: string[];' $stepsField.TrimEnd("`n") 'overrides.ts: notes field'

$helpers = @'

/* Indexing rule: a project page is shown to search engines only when it has
   something of our own on it. Every other page stays open for visitors but
   gets noindex and is left out of the sitemap. */

/** CryptoRank projects that carry task data are indexed even without a hand-written review. Set to false to index only reviewed projects. */
const INDEX_CRYPTORANK_WITH_TASKS = true;

export function hasOwnContent(o?: ProjectOverride): boolean {
  if (!o) return false;
  return Boolean(o.summary || o.steps?.length || o.risks?.length || o.notes?.length);
}

export function isIndexable(p: { slug: string; source?: string; tasks?: unknown[] }): boolean {
  if (hasOwnContent(getOverride(p.slug))) return true;
  if (
    INDEX_CRYPTORANK_WITH_TASKS &&
    String(p.source || "").toLowerCase().includes("cryptorank") &&
    Array.isArray(p.tasks) &&
    p.tasks.length > 0
  ) {
    return true;
  }
  return false;
}
'@
$over = $over.TrimEnd() + "`n" + $helpers.Replace("`r`n", "`n")

# ---- app/project/[slug]/page.tsx ----
$page = Rep $page 'import { getOverride } from "@/lib/overrides";' 'import { getOverride, isIndexable } from "@/lib/overrides";' 'page: import'
$page = Rep $page '    alternates: { canonical: url },' ('    alternates: { canonical: url },' + "`n" + '    robots: isIndexable(p) ? { index: true, follow: true } : { index: false, follow: true },') 'page: robots in generateMetadata'

$oldOv = "  const ov = getOverride(p.slug);`n  const allProjects = await getProjects();"
$newOv = "  const ov = getOverride(p.slug);`n  const steps: string[] = ov?.steps?.length ? ov.steps : (p.actions ?? []);`n  const allProjects = await getProjects();"
$page = Rep $page $oldOv $newOv 'page: steps constant'

$page = Rep $page 'const faqItems = buildFaq(p);' 'const faqItems = buildFaq({ ...p, actions: steps });' 'page: faq'
$page = Rep $page 'const jsonLd = p.actions && p.actions.length ? {' 'const jsonLd = steps.length ? {' 'page: jsonLd condition'
$page = Rep $page '"step": p.actions.map((action, i) => ({' '"step": steps.map((action, i) => ({' 'page: jsonLd steps'
$page = Rep $page '{(p.actions && p.actions.length) || (isCryptoRank' '{steps.length || (isCryptoRank' 'page: guide layout condition'
$page = Rep $page '{p.actions && p.actions.length ? (' '{steps.length ? (' 'page: steps section condition'
$page = Rep $page '<GuideSteps actions={p.actions} slug={p.slug} />' '<GuideSteps actions={steps} slug={p.slug} />' 'page: GuideSteps'

# ---- app/sitemap.ts ----
$map = Rep $map 'import { getOverride } from "@/lib/overrides";' 'import { getOverride, isIndexable } from "@/lib/overrides";' 'sitemap: import'
$map = Rep $map 'projects.map((p) => ({' 'projects.filter((p) => isIndexable(p)).map((p) => ({' 'sitemap: filter'

if ($script:failed) {
  Write-Host "STOPPED: nothing was written. Send me the NOT FOUND lines above."
  exit 1
}

$bakDir = Join-Path $root "_backups"
if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $fOver -Destination (Join-Path $bakDir ("overrides.ts." + $stamp + ".bak"))
Copy-Item -LiteralPath $fPage -Destination (Join-Path $bakDir ("project-page.tsx." + $stamp + ".bak"))
Copy-Item -LiteralPath $fMap  -Destination (Join-Path $bakDir ("sitemap.ts." + $stamp + ".bak"))

[System.IO.File]::WriteAllText($fOver, $over.Replace("`n", "`r`n"), $utf8)
[System.IO.File]::WriteAllText($fPage, $page.Replace("`n", "`r`n"), $utf8)
[System.IO.File]::WriteAllText($fMap,  $map.Replace("`n", "`r`n"),  $utf8)

Write-Host "OK: lib\overrides.ts, app\project\[slug]\page.tsx and app\sitemap.ts updated"