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

$hPath = Join-Path $root "components\Header.tsx"

Patch-File -Path $hPath -Label "Header favorites link" `
  -Old '<Link href="/calendar">Calendar</Link>' `
  -New @'
<Link href="/calendar">Calendar</Link>
        <Link href="/favorites">Favorites</Link>
'@.TrimEnd()

Write-Host ""
Write-Host "Done. Refresh browser and check the top nav for a Favorites link."