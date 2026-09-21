# fix-hubs-23.ps1
# lib\hubs.ts: merge "X Ecosystem" into "X" and skip values that are not real chains/categories
# (Multiple, Other, OwnChain, Unknown, ...).
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\fix-hubs-23.ps1

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

function Count-Of($text, $needle) {
  $c = 0
  $i = 0
  while (($i = $text.IndexOf($needle, $i, [System.StringComparison]::Ordinal)) -ge 0) {
    $c++
    $i += $needle.Length
  }
  return $c
}

$text = [System.IO.File]::ReadAllText($full)

if ($text.Contains("SKIP_NAMES")) {
  Write-Host "SKIP $rel (already patched)"
  exit 0
}

$nl = "`n"
if ($text.Contains("`r`n")) { $nl = "`r`n" }

$find1 = 'function groupBy('
$find2 = 'const raw = (pick(p) || "").trim();'

$repl1 = @'
/** Values that are not real chains/categories: no hub page for them. */
const SKIP_NAMES = new Set([
  "multiple",
  "other",
  "ownchain",
  "unknown",
  "tba",
  "tbd",
  "n/a",
  "none",
]);

/** "Solana Ecosystem" and "Solana" become one hub. */
function cleanName(raw: string): string {
  return raw.trim().replace(/\s+ecosystem$/i, "").trim();
}

function groupBy(
'@

$repl2 = @'
const raw = cleanName(pick(p) || "");
    if (SKIP_NAMES.has(raw.toLowerCase())) continue;
'@

# Verify every fragment first
$failed = $false
foreach ($f in @($find1, $find2)) {
  $cnt = Count-Of $text $f
  if ($cnt -ne 1) {
    Write-Host ("NOT FOUND (" + $cnt + " matches) in " + $rel + ": " + $f)
    $failed = $true
  }
}
if ($failed) {
  Write-Host ""
  Write-Host "Nothing was written. Send me the NOT FOUND line(s) above."
  exit 1
}

$repl1 = $repl1 -replace "`r?`n", $nl
$repl2 = $repl2 -replace "`r?`n", $nl
$text = $text.Replace($find1, $repl1)
$text = $text.Replace($find2, $repl2)

# Backup and write
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null
$name = ($rel -replace '[\\/\[\]]', '_')
Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
[System.IO.File]::WriteAllText($full, $text, $utf8)
Write-Host "PATCHED $rel"
Write-Host ""
Write-Host "DONE. Restart 'npm run dev' and open /airdrops/live"
