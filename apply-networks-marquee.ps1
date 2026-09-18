# apply-networks-marquee.ps1
# Droply: turns the "Top Networks" block on the homepage into an infinite
# marquee with real chain logos (icons from DefiLlama CDN, no API key needed).
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File .\apply-networks-marquee.ps1

$ErrorActionPreference = 'Stop'

$pagePath = Join-Path (Get-Location) 'app\page.tsx'
$cssPath  = Join-Path (Get-Location) 'app\globals.css'

foreach ($p in @($pagePath, $cssPath)) {
    if (-not (Test-Path $p)) {
        Write-Host "NOT FOUND: $p" -ForegroundColor Red
        Write-Host "Run this script from the project root." -ForegroundColor Yellow
        exit 1
    }
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
Copy-Item $pagePath "$pagePath.$stamp.bak"
Copy-Item $cssPath  "$cssPath.$stamp.bak"
Write-Host "Backups created (.bak next to originals)." -ForegroundColor DarkGray

# ---- 1) Replace block in page.tsx (literal string match, no regex) ----

$old = @'
<div className="network-grid">{["Base","Ethereum","Solana","Arbitrum","Aptos","TON"].map(x=><Link href={`/airdrops?chain=${x}`} className="network-card" key={x}><span className="chain-icon">{x[0]}</span><div><b>{x}</b><small>Explore projects</small></div><ArrowRight size={14}/></Link>)}</div>
'@.Trim()

$new = @'
<div className="network-marquee"><div className="network-track">{[...["Base","Ethereum","Solana","Arbitrum","Aptos","TON"],...["Base","Ethereum","Solana","Arbitrum","Aptos","TON"]].map((x,i)=><Link href={`/airdrops?chain=${x}`} className="network-card" key={x+i}><img src={`https://icons.llamao.fi/icons/chains/rsz_${x.toLowerCase()}.jpg`} alt={x} className="chain-icon-img"/><div><b>{x}</b><small>Explore projects</small></div><ArrowRight size={14}/></Link>)}</div></div>
'@.Trim()

$pageContent = [System.IO.File]::ReadAllText($pagePath)

if ($pageContent.Contains($old)) {
    $pageContent = $pageContent.Replace($old, $new)
    [System.IO.File]::WriteAllText($pagePath, $pageContent)
    Write-Host "page.tsx: Top Networks block replaced with marquee." -ForegroundColor Cyan
} else {
    Write-Host "NO EXACT MATCH found in page.tsx (file may have changed)." -ForegroundColor Red
    Write-Host "Nothing was modified. Send Claude the current app\page.tsx." -ForegroundColor Yellow
    exit 1
}

# ---- 2) CSS for the marquee ----

$begin = '/* === DROPLY networks marquee BEGIN === */'
$end   = '/* === DROPLY networks marquee END === */'

$cssLines = @(
    $begin,
    '.network-marquee{overflow:hidden;margin-top:10px;-webkit-mask-image:linear-gradient(90deg,transparent,#000 5%,#000 95%,transparent);mask-image:linear-gradient(90deg,transparent,#000 5%,#000 95%,transparent)}',
    '.network-track{display:flex;gap:8px;width:max-content;animation:networkScroll 40s linear infinite}',
    '.network-track:hover{animation-play-state:paused}',
    '.network-track .network-card{flex:0 0 220px}',
    '.chain-icon-img{width:27px;height:27px;border-radius:50%;object-fit:cover;flex:none;background:#1a2030}',
    '@keyframes networkScroll{from{transform:translateX(0)}to{transform:translateX(-50%)}}',
    $end
)
$cssBlock = [string]::Join([Environment]::NewLine, $cssLines)

$cssContent = Get-Content $cssPath -Raw
$pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end)

if ($cssContent -match $pattern) {
    $cssContent = [regex]::Replace($cssContent, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $cssBlock })
    Write-Host "globals.css: marquee block updated." -ForegroundColor Cyan
} else {
    $cssContent = $cssContent.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $cssBlock + [Environment]::NewLine
    Write-Host "globals.css: marquee block appended." -ForegroundColor Cyan
}

Set-Content -Path $cssPath -Value $cssContent -Encoding UTF8

Write-Host ""
Write-Host "Done. Restart the dev server and hard-refresh the page (Ctrl+Shift+R)." -ForegroundColor Green
Write-Host ("Undo page.tsx:    Copy-Item `"" + $pagePath + "." + $stamp + ".bak`" `"" + $pagePath + "`" -Force") -ForegroundColor DarkGray
Write-Host ("Undo globals.css: Copy-Item `"" + $cssPath + "." + $stamp + ".bak`" `"" + $cssPath + "`" -Force") -ForegroundColor DarkGray
