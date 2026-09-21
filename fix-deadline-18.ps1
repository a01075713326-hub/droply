$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$f = Join-Path $root "lib\date-utils.ts"
if (-not (Test-Path -LiteralPath $f)) { Write-Host "NOT FOUND lib\date-utils.ts"; exit 1 }

$text = [System.IO.File]::ReadAllText($f, $utf8).Replace("`r`n", "`n")
if ($text.Contains("isRealDeadline")) { Write-Host "SKIP: date-utils.ts already patched"; exit 0 }

$script:failed = $false
function Rep([string]$t, [string]$old, [string]$new, [string]$label) {
  $count = $t.Split(@($old), [System.StringSplitOptions]::None).Count - 1
  if ($count -ne 1) {
    Write-Host ("NOT FOUND (or not unique, found " + $count + "): " + $label)
    $script:failed = $true
    return $t
  }
  return $t.Replace($old, $new)
}

$new1 = @'
  const real = parseProjectDate(deadline);
  const d = real ?? parseProjectDate(fallbackDate);
  const isRealDeadline = real !== null;
'@

$new2 = @'
  // A date-only deadline (YYYY-MM-DD) is valid until the end of that day.
  const endOfDay = typeof deadline === "string" && /^\d{4}-\d{2}-\d{2}$/.test(deadline.trim()) ? 24 * 60 * 60 * 1000 : 0;
  const daysLeft = (d.getTime() + (isRealDeadline ? endOfDay : 0) - now.getTime()) / (1000 * 60 * 60 * 24);
'@

$new3 = @'
  // "Ended" only for a real deadline. A fallback date in the past (for example the sync day) does not mean the campaign is over.
  if (daysLeft < 0) return isRealDeadline ? "ended" : null;
'@

$text = Rep $text '  const d = parseProjectDate(deadline) ?? parseProjectDate(fallbackDate);' $new1.Replace("`r`n", "`n") 'date-utils: d line'
$text = Rep $text '  const daysLeft = (d.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);' $new2.Replace("`r`n", "`n") 'date-utils: daysLeft line'
$text = Rep $text '  if (daysLeft < 0) return "ended";' $new3.Replace("`r`n", "`n") 'date-utils: ended line'

if ($script:failed) {
  Write-Host "STOPPED: nothing was written. Send me the NOT FOUND lines above and: Get-Content -LiteralPath .\lib\date-utils.ts"
  exit 1
}

$bakDir = Join-Path $root "_backups"
if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $f -Destination (Join-Path $bakDir ("date-utils.ts." + $stamp + ".bak"))

[System.IO.File]::WriteAllText($f, $text.Replace("`n", "`r`n"), $utf8)
Write-Host "OK: lib\date-utils.ts updated"