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

$pcPath = Join-Path $root "components\ProjectCards.tsx"

# Check imports line was already patched last time (it may have succeeded even though badges failed)
$currentContent = [System.IO.File]::ReadAllText($pcPath, [System.Text.Encoding]::UTF8)
if ($currentContent -notmatch "FavoriteButton") {
    Patch-File -Path $pcPath -Label "PC imports" `
      -Old 'import { initials, cardActions, truncate } from "@/lib/projects";' `
      -New @'
import { initials, cardActions, truncate } from "@/lib/projects";
import FavoriteButton from "@/components/FavoriteButton";
import DeadlineBadge from "@/components/DeadlineBadge";
'@.TrimEnd()
} else {
    Write-Host "SKIP (PC imports): already patched" -ForegroundColor Cyan
}

# Insert star right after the opening <Link ...> tag
Patch-File -Path $pcPath -Label "PC star insert" `
  -Old '<Link className="project-card" href={`/project/${p.slug}`} key={p.id}>' `
  -New @'
<Link className="project-card" href={`/project/${p.slug}`} key={p.id}>
            <FavoriteButton slug={p.slug} />
'@.TrimEnd()

# Insert deadline badge right after the event pills line
Patch-File -Path $pcPath -Label "PC badge insert" `
  -Old '{p.event.split(",").map((e) => <span className="type-pill" key={e}>{e.trim()}</span>)}' `
  -New @'
{p.event.split(",").map((e) => <span className="type-pill" key={e}>{e.trim()}</span>)}
              <DeadlineBadge deadline={p.deadline} date={p.date} />
'@.TrimEnd()

Write-Host ""
Write-Host "Done. Refresh the browser (Ctrl+Shift+R) and check /airdrops."