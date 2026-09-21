# fix-hero-status-33.ps1
# Project page hero: the status pills ("Confirmed", "Live now") were absolutely positioned at the top
# right, right above the "Start Now" button. This moves them into the main column, above the title,
# so the right side holds only the button.
#   app\project\[slug]\page.tsx        : the status block is moved (same markup, new position)
#   app\project\[slug]\hero-status.css : new small stylesheet that overrides the old absolute position
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\fix-hero-status-33.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
$pageRel = "app\project\[slug]\page.tsx"
$cssRel = "app\project\[slug]\hero-status.css"
foreach ($n in @("package.json", $pageRel)) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    Write-Host "Run this script from the project root."
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

$pageFull = [System.IO.Path]::Combine($root, $pageRel)
$cssFull = [System.IO.Path]::Combine($root, $cssRel)
$text = [System.IO.File]::ReadAllText($pageFull)

if ($text.Contains("hero-status.css")) {
  Write-Host "SKIP $pageRel (already patched)"
  exit 0
}

$nl = "`n"
if ($text.Contains("`r`n")) { $nl = "`r`n" }

# ---- 2. Locate the pieces (verify before touching anything) -----------------
$importAnchor = 'import { notFound } from "next/navigation";'
$mainAnchor = '<div className="project-hero__main">'

if ((Count-Of $text $importAnchor) -ne 1) {
  Write-Host ("NOT FOUND (" + (Count-Of $text $importAnchor) + " matches) in " + $pageRel + ": " + $importAnchor)
  exit 1
}
if ((Count-Of $text $mainAnchor) -ne 1) {
  Write-Host ("NOT FOUND (" + (Count-Of $text $mainAnchor) + " matches) in " + $pageRel + ": " + $mainAnchor)
  exit 1
}

$opts = [System.Text.RegularExpressions.RegexOptions]::Singleline
$re = New-Object System.Text.RegularExpressions.Regex('<div className="project-hero__status">.*?</div>', $opts)
$ms = $re.Matches($text)
if ($ms.Count -ne 1) {
  Write-Host ("NOT FOUND (" + $ms.Count + " matches) in " + $pageRel + ": <div className=""project-hero__status"">...</div>")
  exit 1
}
$block = $ms[0].Value
$blockIdx = $ms[0].Index

if ($block.IndexOf("<div", 1, [System.StringComparison]::Ordinal) -ge 0) {
  Write-Host "Unexpected structure: the status block contains a nested div. Nothing was written."
  Write-Host "Send me the part of page.tsx from <section className=""project-hero to <div className=""project-hero__main"">."
  exit 1
}

$mainIdx = $text.IndexOf($mainAnchor, [System.StringComparison]::Ordinal)
if ($mainIdx -lt $blockIdx) {
  Write-Host "The status block is already after the main column. Nothing was written."
  exit 1
}

# ---- 3. Build the new page text ---------------------------------------------
# 3a. cut the block out (together with the whitespace/newline in front of it)
$start = $blockIdx
while (($start -gt 0) -and (($text[$start - 1] -eq ' ') -or ($text[$start - 1] -eq "`t"))) { $start-- }
if (($start -gt 0) -and ($text[$start - 1] -eq "`n")) { $start-- }
if (($start -gt 0) -and ($text[$start - 1] -eq "`r")) { $start-- }
$end = $blockIdx + $block.Length
$text = $text.Remove($start, $end - $start)

# 3b. insert it right after the opening tag of the main column
$mainIdx2 = $text.IndexOf($mainAnchor, [System.StringComparison]::Ordinal)
$insertAt = $mainIdx2 + $mainAnchor.Length
$text = $text.Insert($insertAt, $nl + "          " + $block)

# 3c. import the stylesheet
$importNew = $importAnchor + $nl + 'import "./hero-status.css";'
$text = $text.Replace($importAnchor, $importNew)

# ---- 4. New stylesheet --------------------------------------------------------
$css = @'
/* Project hero: status pills ("Confirmed", "Live now") sit above the title in the main column.
   Three-class selector so it wins over the older two-class rules in globals.css,
   including the ones inside media queries. */
.project-hero--split .project-hero__main > .project-hero__status {
  position: static;
  top: auto;
  right: auto;
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 9px;
  margin: 0 0 10px;
  align-self: auto;
}
'@

# ---- 5. Backup and write ---------------------------------------------------
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null

$pname = ($pageRel -replace '[\\/\[\]]', '_')
Copy-Item -LiteralPath $pageFull -Destination ([System.IO.Path]::Combine($bk, ($pname + "." + $stamp + ".bak")))

if (Test-Path -LiteralPath $cssFull) {
  $cname = ($cssRel -replace '[\\/\[\]]', '_')
  Copy-Item -LiteralPath $cssFull -Destination ([System.IO.Path]::Combine($bk, ($cname + "." + $stamp + ".bak")))
}

[System.IO.File]::WriteAllText($cssFull, $css, $utf8)
Write-Host "WROTE $cssRel"
[System.IO.File]::WriteAllText($pageFull, $text, $utf8)
Write-Host "PATCHED $pageRel"

Write-Host ""
Write-Host "DONE. Reload a project page (for example the Gyndore one) and look at the top block."
