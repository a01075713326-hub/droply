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

# ---------- CalendarCard.tsx (sidebar widget) ----------
$ccPath = Join-Path $root "components\CalendarCard.tsx"
$ccContent = [System.IO.File]::ReadAllText($ccPath, [System.Text.Encoding]::UTF8)
if ($ccContent -notmatch "FavoriteButton") {
    Patch-File -Path $ccPath -Label "CC import" `
      -Old 'import { initials } from "@/lib/projects";' `
      -New @'
import { initials } from "@/lib/projects";
import FavoriteButton from "@/components/FavoriteButton";
'@.TrimEnd()
} else {
    Write-Host "SKIP (CC import): already patched" -ForegroundColor Cyan
}

Patch-File -Path $ccPath -Label "CC mini-event star" `
  -Old '<span>{p.chain}</span></Link>' `
  -New '<span>{p.chain}</span><FavoriteButton slug={p.slug} /></Link>'

# ---------- app/calendar/page.tsx (main list) ----------
$calPath = Join-Path $root "app\calendar\page.tsx"
$calContent = [System.IO.File]::ReadAllText($calPath, [System.Text.Encoding]::UTF8)
if ($calContent -notmatch "FavoriteButton") {
    Patch-File -Path $calPath -Label "Calendar imports" `
      -Old 'import { ArrowUpRight } from "lucide-react";' `
      -New @'
import { ArrowUpRight } from "lucide-react";
import FavoriteButton from "@/components/FavoriteButton";
import DeadlineBadge from "@/components/DeadlineBadge";
'@.TrimEnd()
} else {
    Write-Host "SKIP (Calendar imports): already patched" -ForegroundColor Cyan
}

Patch-File -Path $calPath -Label "Calendar status pill + badge" `
  -Old '<span className={`status-pill ${p.status.toLowerCase()}`}>{p.status}</span>' `
  -New @'
<span className={`status-pill ${p.status.toLowerCase()}`}>{p.status}</span>
              <DeadlineBadge deadline={p.deadline} date={p.date} />
'@.TrimEnd()

Patch-File -Path $calPath -Label "Calendar star before arrow" `
  -Old '<ArrowUpRight size={18} style={{ color: "#647083" }} />' `
  -New @'
<span onClick={(e) => e.stopPropagation()}><FavoriteButton slug={p.slug} /></span>
              <ArrowUpRight size={18} style={{ color: "#647083" }} />
'@.TrimEnd()

# ---------- CSS ----------
$cssPath = Join-Path $root "app\globals.css"
$cssExtra = @"

.mini-event .favorite-btn {
  font-size: 14px;
  padding: 2px;
}
"@
$existingCss = [System.IO.File]::ReadAllText($cssPath, [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($cssPath, $existingCss + $cssExtra, $utf8NoBom)
Write-Host "Appended CSS"

Write-Host ""
Write-Host "Done. Refresh /calendar and check stars + badges."