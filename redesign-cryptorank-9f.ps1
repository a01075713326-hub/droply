# redesign-cryptorank-9f.ps1 (favicon)
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File .\redesign-cryptorank-9f.ps1
#
# - builds app\icon.png (512x512, transparent) and app\apple-icon.png (180x180, dark background)
#   from public\droplet-logo.png using sharp
# - moves the old app\icon.tsx to app\icon.tsx.bak-redesign10 (Next.js would conflict with it)
# Requires: npm install sharp (already done for script 9e)
# NOTE: ASCII-only on purpose.

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath '.\public\droplet-logo.png')) {
  Write-Host 'public\droplet-logo.png not found. Run this from the project root.' -ForegroundColor Red
  exit 1
}
if (-not (Test-Path -LiteralPath '.\node_modules\sharp')) {
  Write-Host 'sharp is not installed. Run: npm install sharp' -ForegroundColor Yellow
  exit 1
}

$js = @'
import sharp from "sharp";

const src = "public/droplet-logo.png";

await sharp(src)
  .resize(512, 512, { fit: "contain", background: { r: 0, g: 0, b: 0, alpha: 0 } })
  .png()
  .toFile("app/icon.png");

await sharp(src)
  .resize(180, 180, { fit: "contain", background: { r: 10, g: 10, b: 20, alpha: 1 } })
  .png()
  .toFile("app/apple-icon.png");

console.log("icons written");
'@

$tmp = '.\make-icons.tmp.mjs'
[System.IO.File]::WriteAllText((Join-Path (Get-Location) 'make-icons.tmp.mjs'), $js, (New-Object System.Text.UTF8Encoding($false)))

try {
  node $tmp
  if ($LASTEXITCODE -ne 0) { throw 'node exited with an error' }
} finally {
  Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath '.\app\icon.tsx') {
  Move-Item -LiteralPath '.\app\icon.tsx' -Destination '.\app\icon.tsx.bak-redesign10' -Force
  Write-Host 'Old app\icon.tsx moved to app\icon.tsx.bak-redesign10' -ForegroundColor Green
}

Get-ChildItem .\app -File | Where-Object { $_.Name -like '*icon*' } | Select-Object Name, Length

Write-Host ''
Write-Host 'Done. Restart the dev server (Ctrl+C, npm run dev), then open a NEW tab and press Ctrl+Shift+R.' -ForegroundColor Green
Write-Host 'Browsers cache favicons hard; if the old one stays, close all droply tabs and reopen.'
