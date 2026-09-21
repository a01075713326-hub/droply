$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

$header = Join-Path $root "components\Header.tsx"
$search = Join-Path $root "components\HeaderSearch.tsx"
$css = Join-Path $root "app\globals.css"
if (-not (Test-Path -LiteralPath $header)) { Write-Host "NOT FOUND components\Header.tsx"; exit 1 }
if (-not (Test-Path -LiteralPath $css)) { Write-Host "NOT FOUND app\globals.css"; exit 1 }

$bakDir = Join-Path $root "_backups"
if (-not (Test-Path -LiteralPath $bakDir)) { New-Item -ItemType Directory -Path $bakDir | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
Copy-Item -LiteralPath $header -Destination (Join-Path $bakDir ("Header.tsx." + $stamp + ".bak"))
Copy-Item -LiteralPath $css -Destination (Join-Path $bakDir ("globals.css." + $stamp + ".bak"))
if (Test-Path -LiteralPath $search) {
  Copy-Item -LiteralPath $search -Destination (Join-Path $bakDir ("HeaderSearch.tsx." + $stamp + ".bak"))
}

$searchCode = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Search } from "lucide-react";

export type SearchItem = { name: string; slug: string; chain: string; logo: string };

function initials(name: string): string {
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0])
    .join("")
    .toUpperCase();
}

export default function HeaderSearch({ items }: { items: SearchItem[] }) {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [active, setActive] = useState(0);
  const [isMac, setIsMac] = useState(false);

  useEffect(() => {
    setIsMac(/Mac|iPhone|iPad/i.test(navigator.platform || navigator.userAgent));
  }, []);

  useEffect(() => {
    function onKey(e: KeyboardEvent) {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === "k") {
        e.preventDefault();
        setOpen(true);
      } else if (e.key === "Escape") {
        setOpen(false);
        setQuery("");
        setActive(0);
      }
    }
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const results = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return [] as SearchItem[];
    const out: { it: SearchItem; s: number }[] = [];
    for (const it of items) {
      const n = it.name.toLowerCase();
      const c = it.chain.toLowerCase();
      let s = -1;
      if (n.startsWith(q)) s = 0;
      else if (n.includes(q)) s = 1;
      else if (c.includes(q)) s = 2;
      if (s >= 0) out.push({ it, s });
    }
    out.sort((a, b) => a.s - b.s);
    return out.slice(0, 8).map((x) => x.it);
  }, [items, query]);

  function close() {
    setOpen(false);
    setQuery("");
    setActive(0);
  }

  function go(slug: string) {
    close();
    router.push("/project/" + encodeURIComponent(slug));
  }

  function onInputKey(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setActive((i) => Math.min(i + 1, Math.max(results.length - 1, 0)));
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setActive((i) => Math.max(i - 1, 0));
    } else if (e.key === "Enter") {
      const r = results[active];
      if (r) go(r.slug);
    }
  }

  return (
    <>
      <button
        type="button"
        className="search-pill"
        onClick={() => setOpen(true)}
        aria-label="Search projects"
      >
        <Search size={16} />
        <span>Search projects, chains, or keywords...</span>
        <kbd>{isMac ? "\u2318K" : "Ctrl K"}</kbd>
      </button>

      {open
        ? createPortal(
            <div className="hs-overlay" onMouseDown={close}>
              <div
                className="hs-panel"
                role="dialog"
                aria-modal="true"
                onMouseDown={(e) => e.stopPropagation()}
              >
                <div className="hs-input-row">
                  <Search size={18} />
                  <input
                    className="hs-input"
                    autoFocus
                    value={query}
                    onChange={(e) => {
                      setQuery(e.target.value);
                      setActive(0);
                    }}
                    onKeyDown={onInputKey}
                    placeholder="Search projects or chains..."
                    aria-label="Search projects or chains"
                  />
                </div>

                <div className="hs-list">
                  {!query.trim() ? (
                    <div className="hs-hint">Start typing a project name or a chain.</div>
                  ) : results.length === 0 ? (
                    <div className="hs-hint">No projects found.</div>
                  ) : (
                    results.map((r, i) => (
                      <Link
                        key={r.slug}
                        href={"/project/" + encodeURIComponent(r.slug)}
                        className={"hs-item" + (i === active ? " active" : "")}
                        onMouseEnter={() => setActive(i)}
                        onClick={close}
                      >
                        <span className="hs-logo">
                          {initials(r.name)}
                          {r.logo ? (
                            <img
                              src={r.logo}
                              alt=""
                              onError={(e) => {
                                e.currentTarget.style.display = "none";
                              }}
                            />
                          ) : null}
                        </span>
                        <span className="hs-text">
                          <span className="hs-name">{r.name}</span>
                          {r.chain ? <span className="hs-chain">{r.chain}</span> : null}
                        </span>
                      </Link>
                    ))
                  )}
                </div>

                <Link href="/airdrops" className="hs-all" onClick={close}>
                  Browse all airdrops
                </Link>
              </div>
            </div>,
            document.body
          )
        : null}
    </>
  );
}
'@

$headerCode = @'
import Link from "next/link";
import { ChevronDown } from "lucide-react";
import DroplyMark from "./DroplyMark";
import HeaderSearch from "./HeaderSearch";
import { getProjects } from "@/lib/projects";

export default async function Header() {
  const all = await getProjects();
  const items = all.map((p) => ({
    name: String(p.name || ""),
    slug: String(p.slug || ""),
    chain: String(p.chain || ""),
    logo: String(p.logo || ""),
  }));

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
        <HeaderSearch items={items} />
      </div>
    </header>
  );
}
'@

$cssAdd = @'

/* ---- Header search ---- */
.hs-overlay { position: fixed; inset: 0; z-index: 1000; background: rgba(3,5,12,.6); backdrop-filter: blur(6px); display: flex; justify-content: center; align-items: flex-start; padding: 12vh 16px 16px; }
.hs-panel { width: 100%; max-width: 560px; background: rgba(14,17,28,.96); border: 1px solid rgba(255,255,255,.12); border-radius: 16px; box-shadow: 0 24px 80px rgba(0,0,0,.55); overflow: hidden; color: #fff; }
.hs-input-row { display: flex; align-items: center; gap: 10px; padding: 14px 16px; border-bottom: 1px solid rgba(255,255,255,.08); }
.hs-input { flex: 1; background: transparent; border: 0; outline: 0; color: inherit; font: inherit; font-size: 16px; }
.hs-input::placeholder { color: rgba(255,255,255,.45); }
.hs-list { max-height: min(60vh, 420px); overflow-y: auto; padding: 6px; }
.hs-item { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border-radius: 10px; color: inherit; text-decoration: none; }
.hs-item.active { background: rgba(255,255,255,.08); }
.hs-logo { position: relative; width: 30px; height: 30px; border-radius: 50%; background: rgba(255,255,255,.1); display: grid; place-items: center; font-size: 11px; font-weight: 700; overflow: hidden; flex: none; }
.hs-logo img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.hs-text { display: flex; flex-direction: column; min-width: 0; }
.hs-name { font-weight: 600; font-size: 14px; }
.hs-chain { font-size: 12px; color: rgba(255,255,255,.55); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.hs-hint { padding: 18px 16px; color: rgba(255,255,255,.55); font-size: 14px; }
.hs-all { display: block; padding: 12px 16px; border-top: 1px solid rgba(255,255,255,.08); color: inherit; font-size: 13px; text-decoration: none; opacity: .8; }
.hs-all:hover { opacity: 1; }
'@

[System.IO.File]::WriteAllText($search, $searchCode, $utf8)
[System.IO.File]::WriteAllText($header, $headerCode, $utf8)
Write-Host "OK: components\HeaderSearch.tsx and components\Header.tsx written"

$cssText = [System.IO.File]::ReadAllText($css, $utf8)
if (-not $cssText.Contains(".hs-overlay")) {
  [System.IO.File]::WriteAllText($css, $cssText + $cssAdd, $utf8)
  Write-Host "OK: search styles appended to globals.css"
} else {
  Write-Host "SKIP: search styles already in globals.css"
}

foreach ($f in @($search, $header)) {
  $t = [System.IO.File]::ReadAllText($f, $utf8)
  foreach ($ch in $t.ToCharArray()) {
    if ([int]$ch -gt 127) { Write-Host ("WARNING: non-ASCII char in " + $f); break }
  }
}
Write-Host "DONE"