$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$f = Join-Path $root "lib\projects.ts"
if (-not (Test-Path -LiteralPath $f)) { Write-Host "NOT FOUND lib\projects.ts"; exit 1 }

$text = [System.IO.File]::ReadAllText($f, $utf8).Replace("`r`n", "`n")
if ($text.Contains("stripReferral")) { Write-Host "SKIP: lib\projects.ts already patched"; exit 0 }

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

$helpers = @'
/* ---- Referral cleanup ----
   Source guides link to their own referral or partner URLs (the source earns the
   commission). Such links are reduced to the plain site address so the site does
   not carry someone else's referral. */

const REF_KEY = /^(?:r|code|via|aff|affiliate|invite\w*|ref\w*|utm_\w+)$/i;
const REF_PATH = /\/(?:ref|refer|referral|referrals|r|invite|join|share|u|b)(?:\/|$)/i;
const REF_HINT = /airdrop-?alert|aalert|airdropaa/i;
const HOST_PREFIX = /^(?:partner|invite|link|go|refer|ref|track|click)\./i;
const SKIP_HOST = /(?:^|\.)(?:discord\.gg|discord\.com|t\.me|telegram\.me|x\.com|twitter\.com|youtube\.com|github\.com|medium\.com)$/i;

function stripReferral(url: string): string {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return url;
  }
  if (SKIP_HOST.test(u.hostname)) return url;

  if (HOST_PREFIX.test(u.hostname) || REF_PATH.test(u.pathname) || REF_HINT.test(url)) {
    return u.protocol + "//" + u.hostname.replace(HOST_PREFIX, "") + "/";
  }

  const keys: string[] = [];
  u.searchParams.forEach((_v, k) => keys.push(k));
  let changed = false;
  for (const k of keys) {
    if (REF_KEY.test(k)) {
      u.searchParams.delete(k);
      changed = true;
    }
  }
  return changed ? u.toString() : url;
}

function cleanStepText(text: string): string {
'@

$stepPatch = @'
    const cleaned = stripReferral(url);
    if (cleaned !== url) {
      removed = true;
      return "[" + label + "](" + cleaned + ")";
    }
    return match;
'@

$linksPatch = @'
  if (out.website && isSourceLink(out.website)) delete out.website;
  if (out.claimUrl) out.claimUrl = stripReferral(out.claimUrl);
  if (out.website) out.website = stripReferral(out.website);
'@

$extraPatch = '    out.extraLinks = out.extraLinks.filter((l) => l && l.url && !isSourceLink(l.url)).map((l) => ({ ...l, url: stripReferral(l.url) }));'

$text = Rep $text 'function cleanStepText(text: string): string {' $helpers.Replace("`r`n", "`n") 'projects.ts: cleanStepText header'
$text = Rep $text '    return match;' $stepPatch.Replace("`r`n", "`n") 'projects.ts: link callback return'
$text = Rep $text '  if (out.website && isSourceLink(out.website)) delete out.website;' $linksPatch.Replace("`r`n", "`n") 'projects.ts: website line'
$text = Rep $text '    out.extraLinks = out.extraLinks.filter((l) => l && l.url && !isSourceLink(l.url));' $extraPatch 'projects.ts: extraLinks line'

if ($script:failed) {
  Write-Host "STOPPED: nothing was written. Send me the NOT FOUND lines above and: Get-Content -LiteralPath .\lib\projects.ts -TotalCount 80"
  exit 1
}

$bakDir = Join-Path $root "_backups"
if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $f -Destination (Join-Path $bakDir ("projects.ts." + $stamp + ".bak"))

[System.IO.File]::WriteAllText($f, $text.Replace("`n", "`r`n"), $utf8)
Write-Host "OK: lib\projects.ts updated (referral links are reduced to plain site addresses)"