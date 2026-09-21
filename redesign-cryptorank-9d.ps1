# redesign-cryptorank-9d.ps1 (sitemap)
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File .\redesign-cryptorank-9d.ps1
#
# Rewrites app\sitemap.ts:
#   - only canonical pages: "/" and "/airdrops" plus every project (no /calendar, it canonicals to /airdrops)
#   - lastModified for a project = the latest REAL event we know about:
#       first seen by sync, your own review (overrides.json updatedAt), verification check date.
#     Future dates are ignored. If none exists, lastModified is left out (better than a fake date).
#   - the list pages get the latest project date instead of "now"
#   - changeFrequency / priority removed (Google ignores them)
# Needs lib\overrides.ts from script 9b.
# Backup: app\sitemap.ts.bak-redesign9d
# NOTE: ASCII-only on purpose.

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

$target = '.\app\sitemap.ts'
if (-not (Test-Path -LiteralPath $target)) {
  Write-Host "File $target not found. Run this from the project root." -ForegroundColor Red
  exit 1
}
if (-not (Test-Path -LiteralPath '.\lib\overrides.ts')) {
  Write-Host 'lib\overrides.ts is missing. Run redesign-cryptorank-9b.ps1 first.' -ForegroundColor Red
  exit 1
}

$path = (Resolve-Path -LiteralPath $target).Path
$old = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
if ($old.Contains('lastModifiedFor')) {
  Write-Host 'Already applied (lastModifiedFor found). Nothing to do.' -ForegroundColor Green
  exit 0
}

$code = @'
import type { MetadataRoute } from "next";
import { getProjects } from "@/lib/projects";
import { getVerification } from "@/lib/verification";
import { getOverride } from "@/lib/overrides";

const BASE = "https://droply.digital";

function toDate(value?: string): Date | null {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d;
}

// Latest real event we know about for a project: first seen by sync,
// our own review, or the verification check. Future dates are ignored.
function lastModifiedFor(p: any): Date | undefined {
  const now = Date.now();
  const dates = [
    toDate(p.firstSeenAt),
    toDate(getOverride(p.slug)?.updatedAt),
    toDate(getVerification(p.slug)?.checkedAt),
  ].filter((d): d is Date => d !== null && d.getTime() <= now);

  if (!dates.length) return undefined;
  return new Date(Math.max(...dates.map((d) => d.getTime())));
}

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const projects = await getProjects();

  const projectRoutes: MetadataRoute.Sitemap = projects.map((p) => ({
    url: `${BASE}/project/${p.slug}`,
    lastModified: lastModifiedFor(p),
  }));

  const stamps = projectRoutes
    .map((r) => (r.lastModified ? new Date(r.lastModified).getTime() : 0))
    .filter((t) => t > 0);
  const listModified = stamps.length ? new Date(Math.max(...stamps)) : undefined;

  // Only canonical pages. /calendar is left out: its canonical points to /airdrops.
  const staticRoutes: MetadataRoute.Sitemap = ["", "/airdrops"].map((route) => ({
    url: `${BASE}${route}`,
    lastModified: listModified,
  }));

  return [...staticRoutes, ...projectRoutes];
}
'@

Copy-Item -LiteralPath $path "${path}.bak-redesign9d"
[System.IO.File]::WriteAllText($path, $code, $utf8)

Write-Host 'app\sitemap.ts rewritten.' -ForegroundColor Green
Write-Host ''
Write-Host 'Check: run npm run dev and open http://localhost:3000/sitemap.xml' -ForegroundColor Green
Write-Host '  - no /calendar'
Write-Host '  - every project has a <lastmod> that is not in the future'
