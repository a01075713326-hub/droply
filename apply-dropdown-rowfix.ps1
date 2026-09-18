$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
Set-Location $root

Write-Host "Working in: $root"

$cssPath = Join-Path $root "app\globals.css"
$css = Get-Content $cssPath -Raw -Encoding UTF8

# 1) Base panel: bigger gap between rows (was 2px)
$oldPanel = '.filter-dropdown-panel{position:absolute;top:calc(100% + 8px);left:0;width:230px;max-height:280px;overflow-y:auto;scroll-behavior:auto;padding:6px;border:1px solid rgba(255,255,255,.11);background:rgba(15,17,21,.99);border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.55);z-index:40;display:flex;flex-direction:column;gap:2px}'
$newPanel = '.filter-dropdown-panel{position:absolute;top:calc(100% + 8px);left:0;width:230px;max-height:280px;overflow-y:auto;scroll-behavior:auto;padding:8px;border:1px solid rgba(255,255,255,.11);background:rgba(15,17,21,.99);border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.55);z-index:40;display:flex;flex-direction:column;gap:6px}'

if ($css.Contains($oldPanel)) {
    $css = $css.Replace($oldPanel, $newPanel)
    Write-Host "Panel gap increased (2px -> 6px), padding 6px -> 8px."
} else {
    Write-Host "WARNING: base .filter-dropdown-panel rule not found as expected - skipped, check manually."
}

# 2) Row buttons: explicit integer line-height + slightly bigger padding, no more ellipsis needed for most values
$oldBtn = '.filter-dropdown-panel button{display:block;width:100%;text-align:left;padding:8px 10px;border-radius:8px;background:none;border:0;color:#b9bec8;font-size:13px;font-weight:600;font-family:inherit;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'
$newBtn = '.filter-dropdown-panel button{display:block;width:100%;text-align:left;padding:10px;line-height:16px;border-radius:8px;background:none;border:0;color:#b9bec8;font-size:13px;font-weight:600;font-family:inherit;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'

if ($css.Contains($oldBtn)) {
    $css = $css.Replace($oldBtn, $newBtn)
    Write-Host "Row buttons now use a fixed integer line-height (16px) and 10px padding."
} else {
    Write-Host "WARNING: .filter-dropdown-panel button rule not found as expected - skipped, check manually."
}

# 3) Remove the chains-only override (spacing is now uniform across all three dropdowns)
$chainsOverride = @'

.chains-dropdown .filter-dropdown-panel{gap:8px;padding:8px}
.chains-dropdown .filter-dropdown-panel button{padding:10px 10px}
'@

if ($css.Contains($chainsOverride)) {
    $css = $css.Replace($chainsOverride, "")
    Write-Host "Removed chains-only spacing override (style is now identical across all three dropdowns)."
} else {
    Write-Host "Chains-only override not found verbatim - leaving as is (may already be clean)."
}

[System.IO.File]::WriteAllText($cssPath, $css, [System.Text.UTF8Encoding]::new($false))
Write-Host "Updated: $cssPath"

Write-Host ""
Write-Host "Done. Restart the dev server if needed and hard-refresh /airdrops."
