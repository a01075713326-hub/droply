$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$target = Join-Path $root "components\Header.tsx"
if (-not (Test-Path -LiteralPath $target)) { Write-Host "NOT FOUND components\Header.tsx"; exit 1 }

$bakDir = Join-Path $root "_backups"
if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $target -Destination (Join-Path $bakDir ("Header.tsx." + $stamp + ".bak"))

$content = @'
import Link from "next/link";
import { ChevronDown, Search } from "lucide-react";
import DroplyMark from "./DroplyMark";

export default function Header() {
  return (
    <header className="site-header">
      <Link href="/" className="brand"><DroplyMark /><span>Droply</span></Link>
      <nav className="desktop-nav">
        <div className="nav-dropdown">
          <button className="glass-btn nav-btn">Airdrops <ChevronDown size={15}/></button>
          <div className="dropdown-panel">
            <div className="drop-group-label">AIRDROPS</div>
            <Link href="/airdrops?status=potential">&#9673; Potential Airdrops</Link>
            <Link href="/airdrops?status=upcoming">&#9676; Upcoming Airdrops</Link>
            <Link href="/airdrops?status=live">&#9679; Live Airdrops</Link>
            <Link href="/airdrops?event=claim">&#10003; Claims</Link>
            <div className="divider"/>
            <div className="drop-group-label">BY BLOCKCHAIN</div>
            {["Base","Solana","Ethereum","Arbitrum","Hyperliquid","Aptos","Sui","TON","ZKsync","Blast"].map((chain) =>
              <Link href={`/airdrops?chain=${encodeURIComponent(chain)}`} key={chain}>{chain}</Link>
            )}
            <Link href="/airdrops" className="show-all">&#8599; Show all</Link>
          </div>
        </div>
        <Link href="/calendar">Calendar</Link>
        <Link href="/favorites">Favorites</Link>
        <Link href="/stats">Stats</Link>
        <Link href="/airdrops">Projects</Link>
      </nav>
      <div className="header-actions">
        <button className="search-pill"><Search size={16}/><span>Search projects, chains, or keywords...</span><kbd>&#8984;K</kbd></button>
      </div>
    </header>
  );
}
'@

$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($target, $content, $utf8)

$check = [System.IO.File]::ReadAllText($target, $utf8)
$bad = $false
foreach ($ch in $check.ToCharArray()) { if ([int]$ch -gt 127) { $bad = $true; break } }
if ($bad) { Write-Host "WARNING: non-ASCII chars found in Header.tsx" } else { Write-Host "OK: Header.tsx rewritten, ASCII only" }