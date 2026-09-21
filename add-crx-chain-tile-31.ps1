# add-crx-chain-tile-31.ps1
# components\CryptoRankDetails.tsx : new first tile "Blockchain" with the chain logo
# (CryptoRank projects did not show the chain anywhere in the overview block).
# The tile is skipped when the chain is not a real chain (Multiple, Other, ...).
# Requires add-chain-icons-cards-28.ps1 to be run first.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\add-crx-chain-tile-31.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
$rel = "components\CryptoRankDetails.tsx"
foreach ($n in @("package.json", $rel, "components\ChainIcon.tsx", "lib\chain-slug.ts")) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    if (($n -like "components\ChainIcon*") -or ($n -like "lib\chain-slug*")) { Write-Host "Run add-chain-icons-cards-28.ps1 first." }
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
$e1Old = 'import MoniGauge from "@/components/MoniGauge";'
$e1New = @'
import MoniGauge from "@/components/MoniGauge";
import ChainIcon from "@/components/ChainIcon";
import { chainSlug } from "@/lib/chain-slug";
'@

$e2Old = 'type Tile = { icon: LucideIcon; label: string; value: string };'
$e2New = 'type Tile = { icon: LucideIcon; label: string; value: string; chain?: string };'

$e3Old = 'tile(CalendarDays, "Opens", fmtDate(starts[0]));'
$e3New = @'
if (chainSlug(p.chain)) tiles.push({ icon: Network, label: "Blockchain", value: p.chain, chain: p.chain });
  tile(CalendarDays, "Opens", fmtDate(starts[0]));
'@

$e4Old = '<Icon size={16} />'
$e4New = '{t.chain ? <ChainIcon chain={t.chain} size={18} /> : <Icon size={16} />}'

$edits = @(
  @{ find = $e1Old; repl = $e1New },
  @{ find = $e2Old; repl = $e2New },
  @{ find = $e3Old; repl = $e3New },
  @{ find = $e4Old; repl = $e4New }
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
Write-Host "DONE. Reload a CryptoRank project page (for example /project/vangrid)."
