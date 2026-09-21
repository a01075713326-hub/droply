# add-menu-icons-27.ps1
# components\Header.tsx : chain logo in front of each name in the BY BLOCKCHAIN dropdown section.
# Requires add-chain-icons-25.ps1 and apply-hubs-22.ps1 to be run first.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\add-menu-icons-27.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
$rel = "components\Header.tsx"
foreach ($n in @("package.json", $rel, "components\ChainIcon.tsx")) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    if ($n -like "components\ChainIcon*") { Write-Host "Run add-chain-icons-25.ps1 first." }
    else { Write-Host "Run this script from the project root." }
    exit 1
  }
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

$full = [System.IO.Path]::Combine($root, $rel)
$text = [System.IO.File]::ReadAllText($full)

if ($text.Contains("ChainIcon")) {
  Write-Host "SKIP $rel (already patched)"
  exit 0
}

$nl = "`n"
if ($text.Contains("`r`n")) { $nl = "`r`n" }

# ---- 2. Fragments ----------------------------------------------------------
$importOld = 'import HeaderSearch from "./HeaderSearch";'
$importNew = @'
import HeaderSearch from "./HeaderSearch";
import ChainIcon from "./ChainIcon";
'@

$linkOld = '<Link href={`/chain/${hub.slug}`} key={hub.slug}>{hub.name}</Link>'
$linkNew = '<Link href={`/chain/${hub.slug}`} key={hub.slug}><span style={{ display: "inline-flex", alignItems: "center", gap: 8 }}><ChainIcon slug={hub.slug} name={hub.name} size={16} />{hub.name}</span></Link>'

$edits = @(
  @{ find = $importOld; repl = $importNew },
  @{ find = $linkOld; repl = $linkNew }
)

# ---- 3. Verify everything first --------------------------------------------
$failed = $false
foreach ($e in $edits) {
  $cnt = Count-Of $text $e.find
  if ($cnt -ne 1) {
    Write-Host ("NOT FOUND (" + $cnt + " matches) in " + $rel + ": " + $e.find)
    $failed = $true
  }
}
if ($failed) {
  Write-Host ""
  Write-Host "Nothing was written. Send me the NOT FOUND line(s) above."
  exit 1
}

foreach ($e in $edits) {
  $r = $e.repl -replace "`r?`n", $nl
  $text = $text.Replace($e.find, $r)
}

# ---- 4. Backup and write ---------------------------------------------------
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null
$name = ($rel -replace '[\\/\[\]]', '_')
Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
[System.IO.File]::WriteAllText($full, $text, $utf8)
Write-Host "PATCHED $rel"
Write-Host ""
Write-Host "DONE. Reload the site and open the Airdrops menu."
