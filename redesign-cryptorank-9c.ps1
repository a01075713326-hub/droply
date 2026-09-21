# redesign-cryptorank-9c.ps1 (clean scraped source data at read time)
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File .\redesign-cryptorank-9c.ps1
#
# What it does (patches lib\projects.ts only):
#   1. Guide steps and task instructions: markdown links that do not work on our domain
#      (/visit/..., /goto/..., any relative link) or that point to airdrops.io / airdropalert.com
#      are turned into plain text (the label stays, the link goes).
#   2. If a link was removed, the sentence "Using this link applies a referral..." is removed too.
#   3. Wrong socials are dropped (t.me/airdrops_io, airdropalert channels, source-site URLs).
#   4. claimUrl / website / extraLinks that point to the source site are dropped.
#   5. The cleaned list is cached once per server start, so every page sees the same data.
# sync.js and data\projects.generated.ts are NOT touched: the cleanup runs when data is read,
# so it also covers data produced by future syncs.
# Backup: lib\projects.ts.bak-redesign9c
# NOTE: ASCII-only on purpose.

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Patch([string]$text, [string]$old, [string]$new, [string]$label) {
  $n = [regex]::Matches($text, [regex]::Escape($old)).Count
  if ($n -ne 1) {
    Write-Host "NOT FOUND (or more than one match): $label (found: $n)" -ForegroundColor Yellow
    return $null
  }
  return $text.Replace($old, $new)
}

$file = '.\lib\projects.ts'
if (-not (Test-Path -LiteralPath $file)) {
  Write-Host "File $file not found. Run this from the project root." -ForegroundColor Red
  exit 1
}
$path = (Resolve-Path -LiteralPath $file).Path
$src = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)

if ($src.Contains('sanitizeProject')) {
  Write-Host 'Already applied (sanitizeProject found). Nothing to do.' -ForegroundColor Green
  exit 0
}

$helper = @'
/* ---- Source cleanup ----
   Guide text scraped from Airdrops.io contains links that do not work on our
   domain (/visit/..., /goto/...) or that send visitors to the source's own
   affiliate and guide pages. They are turned into plain text here, once, so
   every page (lists, project page, sitemap) sees the same clean data. */

const MD_LINK = /\[([^\]]+)\]\(([^)\s]+)\)/g;
const SOURCE_HOST = /^https?:\/\/(?:www\.)?(?:airdrops\.io|airdropalert\.com)(?:[/:?#]|$)/i;
const REFERRAL_SENTENCE = /\s*Using (?:this|our) link[^.]*\./gi;
const BAD_SOCIAL = /(?:t\.me\/airdrops_io|t\.me\/airdropalert\w*|airdrops\.io|airdropalert\.com)/i;

function isSourceLink(url: string): boolean {
  return url.startsWith("/") || SOURCE_HOST.test(url);
}

function cleanStepText(text: string): string {
  if (typeof text !== "string") return text;

  let removed = false;
  const out = text.replace(MD_LINK, (match: string, label: string, url: string) => {
    if (isSourceLink(url)) {
      removed = true;
      return label;
    }
    return match;
  });

  return removed ? out.replace(REFERRAL_SENTENCE, "") : out;
}

function sanitizeProject(p: Project): Project {
  const out: Project = { ...p };

  if (out.actions) out.actions = out.actions.map(cleanStepText);

  if (out.tasks) {
    out.tasks = out.tasks.map((t) =>
      t.instructions ? { ...t, instructions: t.instructions.map(cleanStepText) } : t
    );
  }

  if (out.telegram && BAD_SOCIAL.test(out.telegram)) delete out.telegram;
  if (out.discord && BAD_SOCIAL.test(out.discord)) delete out.discord;
  if (out.x && BAD_SOCIAL.test(out.x)) delete out.x;

  if (out.claimUrl && isSourceLink(out.claimUrl)) delete out.claimUrl;
  if (out.website && isSourceLink(out.website)) delete out.website;

  if (out.extraLinks) {
    out.extraLinks = out.extraLinks.filter((l) => l && l.url && !isSourceLink(l.url));
  }

  return out;
}

let cleanCache: Project[] | null = null;

function getCleanProjects(): Project[] {
  if (!cleanCache) cleanCache = allProjects.map(sanitizeProject);
  return cleanCache;
}

'@

$s = Patch $src 'export async function getProjects(): Promise<Project[]> {' ($helper + 'export async function getProjects(): Promise<Project[]> {') 'insert helpers'
if ($null -eq $s) { exit 1 }

$s = Patch $s 'return allProjects;' 'return getCleanProjects();' 'return cleaned list'
if ($null -eq $s) { exit 1 }

Copy-Item -LiteralPath $path "${path}.bak-redesign9c"
[System.IO.File]::WriteAllText($path, $s, $utf8)

Write-Host 'lib\projects.ts updated.' -ForegroundColor Green
Write-Host ''
Write-Host 'Now restart the dev server (Ctrl+C, then npm run dev) and open /project/baibai:' -ForegroundColor Green
Write-Host '  - the steps should have no /visit/ links (labels stay as plain text)'
Write-Host '  - the Telegram link should be gone from the Links panel (baibai had t.me/airdrops_io)'
