# fix-live-24.ps1
# lib\hubs.ts: a project counts as live if status is "Live" OR the isLive flag is true.
# (In the data no project has status "Live", but 18 have isLive: true.)
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\fix-live-24.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$rel = "lib\hubs.ts"
$full = [System.IO.Path]::Combine($root, $rel)
if (-not (Test-Path -LiteralPath $full)) {
  Write-Host "NOT FOUND $rel"
  Write-Host "Run this script from the project root (after add-hubs-21.ps1)."
  exit 1
}

$text = [System.IO.File]::ReadAllText($full)

if ($text.Contains("p.isLive === true")) {
  Write-Host "SKIP $rel (already patched)"
  exit 0
}

$find = 'return projects.filter((p) => p.status === "Live");'
$repl = 'return projects.filter((p) => p.status === "Live" || p.isLive === true);'

$idx = $text.IndexOf($find, [System.StringComparison]::Ordinal)
if ($idx -lt 0) {
  Write-Host ("NOT FOUND in " + $rel + ": " + $find)
  Write-Host "Nothing was written. Send me this line."
  exit 1
}
$idx2 = $text.IndexOf($find, $idx + $find.Length, [System.StringComparison]::Ordinal)
if ($idx2 -ge 0) {
  Write-Host ("FOUND MORE THAN ONCE in " + $rel + ": " + $find)
  Write-Host "Nothing was written."
  exit 1
}

$text = $text.Replace($find, $repl)

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null
$name = ($rel -replace '[\\/\[\]]', '_')
Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
[System.IO.File]::WriteAllText($full, $text, $utf8)
Write-Host "PATCHED $rel"
Write-Host ""
Write-Host "DONE. Restart 'npm run dev' and open /airdrops/live"
