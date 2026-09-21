# add-mobile-nav-32.ps1
# Mobile / tablet header: the desktop nav is hidden below 1050px and the search below 760px,
# so phones had only the logo. This adds:
#   - a hamburger button (shown below 1050px) that opens a full-screen menu panel
#   - the search button back on phones, as an icon-only button
# New files:  components\MobileNav.tsx, components\mobile-nav.css
# Patched:    components\Header.tsx (2 lines)
# Requires add-chain-icons-cards-28.ps1 and apply-hubs-22.ps1 to be run first.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\add-mobile-nav-32.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check files ---------------------------------------------------------
$headerRel = "components\Header.tsx"
foreach ($n in @("package.json", $headerRel, "components\ChainIcon.tsx")) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    if ($n -like "components\ChainIcon*") { Write-Host "Run add-chain-icons-cards-28.ps1 first." }
    else { Write-Host "Run this script from the project root." }
    exit 1
  }
}

# ChainIcon must be the new client-safe version (uses /chain-icon/<slug>, no fs)
$iconText = [System.IO.File]::ReadAllText([System.IO.Path]::Combine($root, "components\ChainIcon.tsx"))
if (-not $iconText.Contains("/chain-icon/")) {
  Write-Host "components\ChainIcon.tsx is the old version. Run add-chain-icons-cards-28.ps1 first."
  exit 1
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

# ---- 2. New files -----------------------------------------------------------
$mobileNav = @'
"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { Menu, X } from "lucide-react";
import ChainIcon from "@/components/ChainIcon";
import "./mobile-nav.css";

type Chain = { slug: string; name: string };

export default function MobileNav({ chains }: { chains: Chain[] }) {
  const [open, setOpen] = useState(false);
  const [mounted, setMounted] = useState(false);
  const pathname = usePathname();

  useEffect(() => {
    setMounted(true);
  }, []);

  // close after navigation
  useEffect(() => {
    setOpen(false);
  }, [pathname]);

  // Escape closes, page does not scroll behind the panel
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setOpen(false);
    };
    window.addEventListener("keydown", onKey);
    const prev = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      window.removeEventListener("keydown", onKey);
      document.body.style.overflow = prev;
    };
  }, [open]);

  const close = () => setOpen(false);

  // The panel is rendered into document.body: the sticky header has backdrop-filter,
  // which would otherwise trap a position:fixed child inside the 68px header.
  const panel = (
    <nav id="mnav-panel" className="mnav-panel" aria-label="Main menu">
      <div className="mnav-label">AIRDROPS</div>
      <div className="mnav-links">
        <Link href="/airdrops" onClick={close}>All airdrops</Link>
        <Link href="/airdrops?status=potential" onClick={close}>Potential airdrops</Link>
        <Link href="/airdrops?status=upcoming" onClick={close}>Upcoming airdrops</Link>
        <Link href="/airdrops/live" onClick={close}>Live airdrops</Link>
      </div>

      {chains.length ? (
        <>
          <div className="mnav-label">BY BLOCKCHAIN</div>
          <div className="mnav-chains">
            {chains.map((c) => (
              <Link key={c.slug} href={`/chain/${c.slug}`} onClick={close}>
                <ChainIcon slug={c.slug} name={c.name} size={18} />
                {c.name}
              </Link>
            ))}
          </div>
        </>
      ) : null}

      <div className="mnav-divider" />
      <div className="mnav-links">
        <Link href="/calendar" onClick={close}>Calendar</Link>
        <Link href="/favorites" onClick={close}>Favorites</Link>
        <Link href="/stats" onClick={close}>Stats</Link>
      </div>
    </nav>
  );

  return (
    <>
      <button
        type="button"
        className="mnav-btn"
        aria-label={open ? "Close menu" : "Open menu"}
        aria-expanded={open}
        aria-controls="mnav-panel"
        onClick={() => setOpen((v) => !v)}
      >
        {open ? <X size={20} /> : <Menu size={20} />}
      </button>
      {mounted && open ? createPortal(panel, document.body) : null}
    </>
  );
}
'@

$mobileCss = @'
/* Mobile / tablet menu. Prefix mnav- keeps it away from the existing styles. */

.mnav-btn {
  display: none;
  align-items: center;
  justify-content: center;
  width: 42px;
  height: 42px;
  padding: 0;
  border: 1px solid rgba(255, 255, 255, 0.12);
  background: rgba(255, 255, 255, 0.045);
  color: #eef2f8;
  border-radius: 11px;
  cursor: pointer;
}
.mnav-btn:hover {
  background: rgba(255, 255, 255, 0.09);
}
.mnav-btn:focus-visible {
  outline: 2px solid #8b5cf6;
  outline-offset: 2px;
}

/* the desktop nav is hidden at this width, so the hamburger takes over */
@media (max-width: 1050px) {
  .mnav-btn {
    display: inline-flex;
  }
}

/* phones: bring the search back as an icon-only button */
@media (max-width: 760px) {
  .site-header .header-actions {
    display: flex;
    gap: 8px;
  }
  .site-header .search-pill {
    width: 42px;
    height: 42px;
    padding: 0;
    justify-content: center;
  }
  .site-header .search-pill span,
  .site-header .search-pill kbd {
    display: none;
  }
}

.mnav-panel {
  position: fixed;
  top: 68px;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 60;
  overflow-y: auto;
  padding: 12px 18px calc(40px + env(safe-area-inset-bottom, 0px));
  background: rgba(5, 7, 10, 0.97);
  backdrop-filter: blur(18px);
  -webkit-overflow-scrolling: touch;
}
@media (min-width: 1051px) {
  .mnav-panel {
    display: none;
  }
}

.mnav-label {
  font-size: 12px;
  color: #8a96ab;
  letter-spacing: 1.3px;
  padding: 16px 4px 6px;
}
.mnav-links {
  display: grid;
  gap: 2px;
}
.mnav-links a {
  display: flex;
  align-items: center;
  gap: 10px;
  min-height: 46px;
  padding: 0 10px;
  border-radius: 10px;
  color: #d5dae4;
  font-size: 15px;
  font-weight: 600;
}
.mnav-links a:hover,
.mnav-links a:active {
  background: rgba(255, 255, 255, 0.07);
  color: #fff;
}
.mnav-chains {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding: 4px 0;
}
.mnav-chains a {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  min-height: 40px;
  padding: 0 14px 0 10px;
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.035);
  color: #d5dae4;
  font-size: 14px;
  font-weight: 600;
}
.mnav-chains a:hover,
.mnav-chains a:active {
  background: rgba(255, 255, 255, 0.08);
  color: #fff;
}
.mnav-divider {
  height: 1px;
  background: rgba(255, 255, 255, 0.08);
  margin: 16px 0 6px;
}
'@

# ---- 3. Header.tsx edits (verify first) ------------------------------------
$headerFull = [System.IO.Path]::Combine($root, $headerRel)
$text = [System.IO.File]::ReadAllText($headerFull)

if ($text.Contains("MobileNav")) {
  Write-Host "SKIP $headerRel (already patched)"
  exit 0
}
if (-not $text.Contains("menuChains")) {
  Write-Host "menuChains not found in $headerRel. Run apply-hubs-22.ps1 first."
  exit 1
}

$nl = "`n"
if ($text.Contains("`r`n")) { $nl = "`r`n" }

$importOld = 'import HeaderSearch from "./HeaderSearch";'
$importNew = @'
import HeaderSearch from "./HeaderSearch";
import MobileNav from "./MobileNav";
'@

$useOld = '<HeaderSearch items={items} />'
$useNew = @'
<HeaderSearch items={items} />
        <MobileNav chains={menuChains.map((h) => ({ slug: h.slug, name: h.name }))} />
'@

$edits = @(
  @{ find = $importOld; repl = $importNew },
  @{ find = $useOld; repl = $useNew }
)

$failed = $false
foreach ($e in $edits) {
  $cnt = Count-Of $text $e.find
  if ($cnt -ne 1) {
    Write-Host ("NOT FOUND (" + $cnt + " matches) in " + $headerRel + ": " + $e.find)
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

function Write-New($rel, $content) {
  $full = [System.IO.Path]::Combine($root, $rel)
  if (Test-Path -LiteralPath $full) {
    $name = ($rel -replace '[\\/\[\]]', '_')
    Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
  }
  [System.IO.File]::WriteAllText($full, $content, $utf8)
  Write-Host "WROTE $rel"
}

Write-New "components\MobileNav.tsx" $mobileNav
Write-New "components\mobile-nav.css" $mobileCss

$hname = ($headerRel -replace '[\\/\[\]]', '_')
Copy-Item -LiteralPath $headerFull -Destination ([System.IO.Path]::Combine($bk, ($hname + "." + $stamp + ".bak")))
[System.IO.File]::WriteAllText($headerFull, $text, $utf8)
Write-Host "PATCHED $headerRel"

Write-Host ""
Write-Host "DONE. Restart 'npm run dev' and check the site at phone width (F12, Ctrl+Shift+M)."
