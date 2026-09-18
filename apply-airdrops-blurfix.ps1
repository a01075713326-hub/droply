$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
Set-Location $root

Write-Host "Working in: $root"

$cssPath = Join-Path $root "app\globals.css"
$css = Get-Content $cssPath -Raw -Encoding UTF8

$old = '.filter-dropdown-panel{position:absolute;top:calc(100% + 8px);left:0;width:230px;max-height:280px;overflow-y:auto;padding:6px;border:1px solid rgba(255,255,255,.11);background:rgba(21,24,29,.97);backdrop-filter:blur(24px);border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.55);z-index:40;display:flex;flex-direction:column;gap:2px}'
$new = '.filter-dropdown-panel{position:absolute;top:calc(100% + 8px);left:0;width:230px;max-height:280px;overflow-y:auto;padding:6px;border:1px solid rgba(255,255,255,.11);background:rgba(15,17,21,.99);border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.55);z-index:40;display:flex;flex-direction:column;gap:2px}'

if ($css.Contains($old)) {
    $css = $css.Replace($old, $new)
    [System.IO.File]::WriteAllText($cssPath, $css, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Removed backdrop-filter from scrollable dropdown panel (fixes text blur while scrolling)."
} else {
    Write-Host "WARNING: expected .filter-dropdown-panel rule not found - no changes made, check manually."
}

Write-Host ""
Write-Host "Done. Restart the dev server if needed and hard-refresh /airdrops."
