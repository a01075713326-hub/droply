$root = "C:\Users\Sasa\Desktop\zip"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Patch-File {
    param([string]$Path, [string]$Old, [string]$New, [string]$Label)
    $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $count = ([regex]::Matches($content, [regex]::Escape($Old))).Count
    if ($count -eq 0) {
        Write-Host "SKIP ($Label): old string not found in $Path" -ForegroundColor Yellow
        return
    }
    if ($count -gt 1) {
        Write-Host "SKIP ($Label): old string found $count times in $Path (not unique, not patching)" -ForegroundColor Yellow
        return
    }
    $updated = $content.Replace($Old, $New)
    [System.IO.File]::WriteAllText($Path, $updated, $utf8NoBom)
    Write-Host "OK ($Label): patched $Path"
}

function Write-FileUtf8 {
    param([string]$Path, [string]$Content)
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "Wrote: $Path"
}

# ---------- ProjectTable.tsx ----------
$ptPath = Join-Path $root "components\ProjectTable.tsx"

Patch-File -Path $ptPath -Label "PT imports" `
  -Old 'import { formatDate, initials, truncate } from "@/lib/projects";' `
  -New "import { formatDate, initials, truncate } from `"@/lib/projects`";`nimport FavoriteButton from `"@/components/FavoriteButton`";`nimport DeadlineBadge from `"@/components/DeadlineBadge`";"

Patch-File -Path $ptPath -Label "PT date cell" `
  -Old '<div className="muted">{formatDate(p.date)}</div>' `
  -New '<div className="muted">{formatDate(p.date)}<DeadlineBadge deadline={p.deadline} date={p.date} /></div>'

Patch-File -Path $ptPath -Label "PT actions cell" `
  -Old "          <div><span className={`status-pill `${p.status.toLowerCase()}`}>{p.status}</span></div>`n          <ChevronRight className=`"row-arrow`" size={17}/>" `
  -New "          <div><span className={`status-pill `${p.status.toLowerCase()}`}>{p.status}</span></div>`n          <div className=`"row-actions`" onClick={(e) => e.stopPropagation()}>`n            <FavoriteButton slug={p.slug} />`n            <ChevronRight className=`"row-arrow`" size={17}/>`n          </div>"

# ---------- app/project/[slug]/page.tsx ----------
$ppPath = Join-Path $root "app\project\[slug]\page.tsx"

Patch-File -Path $ppPath -Label "PP imports" `
  -Old 'import GuideSteps from "@/components/GuideSteps";' `
  -New "import GuideSteps from `"@/components/GuideSteps`";`nimport FavoriteButton from `"@/components/FavoriteButton`";`nimport DeadlineBadge from `"@/components/DeadlineBadge`";"

Patch-File -Path $ppPath -Label "PP status row" `
  -Old "         <span style={{ display: `"flex`", alignItems: `"center`", gap: 8 }}>`n          <span className={`status-pill `${p.status.toLowerCase()}`}>{p.status}</span>" `
  -New "         <span style={{ display: `"flex`", alignItems: `"center`", gap: 8 }}>`n          <FavoriteButton slug={p.slug} />`n          <span className={`status-pill `${p.status.toLowerCase()}`}>{p.status}</span>`n          <DeadlineBadge deadline={p.deadline} date={p.date} />"

# ---------- New: components/FavoritesList.tsx ----------
$favoritesListContent = @'
"use client";
import { Project } from "@/data/projects";
import { useFavorites } from "@/hooks/useFavorites";
import ProjectTable from "@/components/ProjectTable";

export default function FavoritesList({ items }: { items: Project[] }) {
  const { favorites } = useFavorites();
  const filtered = items.filter((p) => favorites.includes(p.slug));

  if (!filtered.length) {
    return (
      <p className="muted" style={{ padding: "40px 0", textAlign: "center" }}>
        No favorites yet. Click the star on any drop to save it here.
      </p>
    );
  }

  return <ProjectTable items={filtered} />;
}
'@
Write-FileUtf8 -Path (Join-Path $root "components\FavoritesList.tsx") -Content $favoritesListContent

# ---------- New: app/favorites/page.tsx ----------
$favoritesPageContent = @'
import { getProjects } from "@/lib/projects";
import FavoritesList from "@/components/FavoritesList";

export default async function FavoritesPage() {
  const projects = await getProjects();
  return (
    <main className="page container">
      <h1>Your Favorites</h1>
      <FavoritesList items={projects} />
    </main>
  );
}
'@
Write-FileUtf8 -Path (Join-Path $root "app\favorites\page.tsx") -Content $favoritesPageContent

# ---------- CSS for .row-actions ----------
$cssPath = Join-Path $root "app\globals.css"
$cssExtra = @"

.row-actions {
  display: flex;
  align-items: center;
  gap: 6px;
}
"@
$existingCss = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($cssPath, $existingCss + $cssExtra, $utf8NoBom)
Write-Host "Appended .row-actions CSS"

Write-Host ""
Write-Host "Done. Run 'npm run dev' and check:"
Write-Host "  - star on table rows (/airdrops) and on project page"
Write-Host "  - Ending Soon / Ended badges next to dates"
Write-Host "  - /favorites page"