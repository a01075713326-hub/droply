# fetch-chain-logos-26.ps1
# 1) lib\chain-icons.ts : allow .jpg files (DefiLlama icons are jpg)
# 2) Finds every chain that has a hub page (3+ projects) and downloads its logo into public\chains\
#    Sources tried in order: DefiLlama chain icons, then TrustWallet assets (GitHub).
# Existing files in public\chains are never overwritten.
# Needs internet on YOUR machine. Run add-chain-icons-25.ps1 first.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\fetch-chain-logos-26.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }

# ---- 1. Checks --------------------------------------------------------------
$iconLibRel = "lib\chain-icons.ts"
$iconLib = [System.IO.Path]::Combine($root, $iconLibRel)
$dataFile = [System.IO.Path]::Combine($root, "data\projects.generated.ts")

foreach ($n in @("package.json", "data\projects.generated.ts")) {
  if (-not (Test-Path -LiteralPath ([System.IO.Path]::Combine($root, $n)))) {
    Write-Host "NOT FOUND $n"
    Write-Host "Run this script from the project root."
    exit 1
  }
}
if (-not (Test-Path -LiteralPath $iconLib)) {
  Write-Host "NOT FOUND $iconLibRel"
  Write-Host "Run add-chain-icons-25.ps1 first."
  exit 1
}

# ---- 2. Allow .jpg in the icon lookup --------------------------------------
$libText = [System.IO.File]::ReadAllText($iconLib)
$findExt = 'const EXTS = ["svg", "png", "webp"];'
$replExt = 'const EXTS = ["svg", "png", "webp", "jpg"];'

if ($libText.Contains('"jpg"')) {
  Write-Host "SKIP $iconLibRel (jpg already allowed)"
} else {
  $first = $libText.IndexOf($findExt, [System.StringComparison]::Ordinal)
  if ($first -lt 0) {
    Write-Host ("NOT FOUND in " + $iconLibRel + ": " + $findExt)
    Write-Host "Nothing was written. Send me this line."
    exit 1
  }
  $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $bk = [System.IO.Path]::Combine($root, "_backups")
  [System.IO.Directory]::CreateDirectory($bk) | Out-Null
  $bname = ($iconLibRel -replace '[\\/\[\]]', '_')
  Copy-Item -LiteralPath $iconLib -Destination ([System.IO.Path]::Combine($bk, ($bname + "." + $stamp + ".bak")))
  $libText = $libText.Replace($findExt, $replExt)
  [System.IO.File]::WriteAllText($iconLib, $libText, $utf8)
  Write-Host "PATCHED $iconLibRel"
}

# ---- 3. Which chains have a hub page? (same rules as lib\hubs.ts) ----------
$dataText = [System.IO.File]::ReadAllText($dataFile)
$skip = @("multiple", "other", "ownchain", "unknown", "tba", "tbd", "n/a", "none")
$counts = @{}
$names = @{}
$matches1 = [regex]::Matches($dataText, '(?m)^\s*"?chain"?\s*:\s*"([^"]*)"')
foreach ($m in $matches1) {
  $raw = $m.Groups[1].Value
  $name = ($raw.Trim() -replace '\s+ecosystem$', '').Trim()
  if ($name.Length -eq 0) { continue }
  if ($skip -contains $name.ToLower()) { continue }
  $slug = ($name.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
  if ($slug.Length -eq 0) { continue }
  if (-not $counts.ContainsKey($slug)) { $counts[$slug] = 0; $names[$slug] = $name }
  $counts[$slug] = $counts[$slug] + 1
}
$slugs = @($counts.Keys | Where-Object { $counts[$_] -ge 3 } | Sort-Object { -$counts[$_] })
Write-Host ("Chains with a hub page: " + $slugs.Count)

# ---- 4. Name mapping for the two sources -----------------------------------
$llamaNames = @{
  "bnb-chain"   = @("binance", "bsc")
  "hyperliquid" = @("hyperliquid", "hyperliquid_l1")
  "zksync"      = @("era", "zksync_era", "zksync")
  "op-mainnet"  = @("optimism")
}
$twNames = @{
  "bnb-chain" = @("smartchain")
  "avalanche" = @("avalanchec")
}

$outDir = [System.IO.Path]::Combine($root, "public\chains")
[System.IO.Directory]::CreateDirectory($outDir) | Out-Null

function Try-Download($url, $slug) {
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 20
  } catch {
    return $false
  }
  if ($r.StatusCode -ne 200) { return $false }
  $ct = [string]$r.Headers["Content-Type"]
  $ext = $null
  if ($ct -like "image/jpeg*") { $ext = "jpg" }
  elseif ($ct -like "image/png*") { $ext = "png" }
  elseif ($ct -like "image/webp*") { $ext = "webp" }
  elseif ($ct -like "image/svg*") { $ext = "svg" }
  if (-not $ext) { return $false }
  $bytes = $r.Content
  if (($bytes -isnot [byte[]]) -or ($bytes.Length -lt 300)) { return $false }
  $dest = [System.IO.Path]::Combine($outDir, ($slug + "." + $ext))
  [System.IO.File]::WriteAllBytes($dest, $bytes)
  return $true
}

# ---- 5. Download ------------------------------------------------------------
$ok = @()
$missing = @()
$had = @()

foreach ($slug in $slugs) {
  $existing = Get-ChildItem -LiteralPath $outDir -File -ErrorAction SilentlyContinue | Where-Object { $_.BaseName -eq $slug }
  if ($existing) { $had += $slug; continue }

  $urls = @()
  $ln = @($slug, ($slug -replace '-', '_'))
  if ($llamaNames.ContainsKey($slug)) { $ln = $llamaNames[$slug] + $ln }
  foreach ($n in ($ln | Select-Object -Unique)) {
    $urls += ("https://icons.llamao.fi/icons/chains/rsz_" + $n + ".jpg")
  }
  $tn = @($slug)
  if ($twNames.ContainsKey($slug)) { $tn = $twNames[$slug] + $tn }
  foreach ($n in ($tn | Select-Object -Unique)) {
    $urls += ("https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/" + $n + "/info/logo.png")
  }

  $done = $false
  foreach ($u in $urls) {
    if (Try-Download $u $slug) { $done = $true; break }
  }
  if ($done) { $ok += $slug; Write-Host ("OK      " + $slug) }
  else { $missing += $slug; Write-Host ("MISSING " + $slug) }
}

Write-Host ""
Write-Host ("Downloaded: " + $ok.Count + ", already there: " + $had.Count + ", not found: " + $missing.Count)
if ($missing.Count -gt 0) {
  Write-Host ("Not found (letter badge stays): " + ($missing -join ", "))
}
Write-Host ""
Write-Host "DONE. Reload /airdrops/live (no restart needed). If a logo looks wrong, delete that file from public\chains."
