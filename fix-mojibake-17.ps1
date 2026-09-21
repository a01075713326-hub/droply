$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$fSync = Join-Path $root "scripts\sync.js"
$fGen  = Join-Path $root "data\projects.generated.ts"
foreach ($f in @($fSync, $fGen)) {
  if (-not (Test-Path -LiteralPath $f)) { Write-Host ("NOT FOUND " + $f); exit 1 }
}

$bakDir = Join-Path $root "_backups"
if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $fSync -Destination (Join-Path $bakDir ("sync.js." + $stamp + ".bak"))
Copy-Item -LiteralPath $fGen -Destination (Join-Path $bakDir ("projects.generated.ts." + $stamp + ".bak"))

$script:enc1251 = [System.Text.Encoding]::GetEncoding(1251, (New-Object System.Text.EncoderExceptionFallback), (New-Object System.Text.DecoderExceptionFallback))
$script:utf8Strict = New-Object System.Text.UTF8Encoding($false, $true)

# ---------- Part 1: data\projects.generated.ts ----------
$script:fixedRuns = 0
$script:skipped = @{}
$evaluator = [System.Text.RegularExpressions.MatchEvaluator]{
  param($m)
  $run = $m.Value
  try {
    $bytes = $script:enc1251.GetBytes($run)
    $back = $script:utf8Strict.GetString($bytes)
    $script:fixedRuns++
    return $back
  } catch {
    if ($script:skipped.ContainsKey($run)) { $script:skipped[$run]++ } else { $script:skipped[$run] = 1 }
    return $run
  }
}

$genText = [System.IO.File]::ReadAllText($fGen, $utf8)
$genNew = [regex]::Replace($genText, '[^\x00-\x7F]+', $evaluator)
Write-Host ("generated data: repaired " + $script:fixedRuns + " garbled sequences")
Write-Host ("generated data: left untouched " + $script:skipped.Count + " different non-ASCII sequences (normal characters or unrepairable)")
$shown = 0
foreach ($k in $script:skipped.Keys) {
  if ($shown -ge 15) { break }
  Write-Host ("   kept: " + $k + "  x" + $script:skipped[$k])
  $shown++
}

# ---------- Part 2: scripts\sync.js ----------
$syncText = [System.IO.File]::ReadAllText($fSync, $utf8).Replace("`r`n", "`n")
$lines = $syncText.Split("`n")

$start = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
  if ($lines[$i] -match 'NAMED_ENTITIES') { $start = $i; break }
}
if ($start -lt 0) { Write-Host "NOT FOUND NAMED_ENTITIES in scripts\sync.js"; exit 1 }

$dict = @{
  mdash = 0x2014; ndash = 0x2013; rarr = 0x2192; larr = 0x2190; hellip = 0x2026;
  trade = 0x2122; copy = 0x00A9; reg = 0x00AE; times = 0x00D7; nbsp = 0x00A0;
  lsquo = 0x2018; rsquo = 0x2019; ldquo = 0x201C; rdquo = 0x201D; bull = 0x2022;
  middot = 0x00B7; laquo = 0x00AB; raquo = 0x00BB; euro = 0x20AC; deg = 0x00B0; plusmn = 0x00B1
}

$fixedKeys = @()
$unknownKeys = @()
for ($i = $start + 1; $i -lt $lines.Length; $i++) {
  $ln = $lines[$i]
  if ($ln.Trim().StartsWith("}")) { break }
  if ($ln -match '^(\s*)([A-Za-z0-9_]+):\s*"([^"]*)"(,?)\s*$') {
    $indent = $matches[1]; $key = $matches[2]; $val = $matches[3]; $comma = $matches[4]
    if ($val -match '[^\x00-\x7F]') {
      $esc = ""
      if ($dict.ContainsKey($key)) {
        $esc = "\u" + ("{0:X4}" -f $dict[$key])
      } else {
        try {
          $dec = $script:utf8Strict.GetString($script:enc1251.GetBytes($val))
          foreach ($ch in $dec.ToCharArray()) { $esc += "\u" + ("{0:X4}" -f [int]$ch) }
        } catch { $esc = "" }
      }
      if ($esc -ne "") {
        $lines[$i] = $indent + $key + ': "' + $esc + '"' + $comma
        $fixedKeys += $key
      } else {
        $unknownKeys += $key
      }
    }
  }
}

$syncNew = $lines -join "`n"
$joinPat = '\.join\(" [^\x00-\x7F]+ "\)'
$joinCount = [regex]::Matches($syncNew, $joinPat).Count
if ($joinCount -gt 0) { $syncNew = [regex]::Replace($syncNew, $joinPat, '.join(" \u2014 ")') }

Write-Host ("sync.js: fixed entity keys: " + ($fixedKeys -join ", "))
if ($unknownKeys.Count -gt 0) { Write-Host ("sync.js: NOT repaired keys (send me these lines): " + ($unknownKeys -join ", ")) }
Write-Host ("sync.js: fixed join separators: " + $joinCount)

$left = @()
$all = $syncNew.Split("`n")
for ($i = 0; $i -lt $all.Length; $i++) {
  $t = $all[$i].Trim()
  if ($t.StartsWith("//") -or $t.StartsWith("/*") -or $t.StartsWith("*")) { continue }
  if ($all[$i] -match '[^\x00-\x7F]') { $left += ($i + 1) }
}
if ($left.Count -gt 0) { Write-Host ("sync.js: non-ASCII still on code lines: " + (($left | Select-Object -First 20) -join ", ")) }

[System.IO.File]::WriteAllText($fGen, $genNew, $utf8)
[System.IO.File]::WriteAllText($fSync, $syncNew.Replace("`n", "`r`n"), $utf8)
Write-Host "DONE: backups are in _backups"