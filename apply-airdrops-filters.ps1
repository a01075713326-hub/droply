$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
Set-Location $root

Write-Host "Working in: $root"

# 1) components/AirdropsExplorer.tsx
$explorer = @'
"use client";

import { useMemo, useState } from "react";
import ProjectCards from "@/components/ProjectCards";
import { Project } from "@/data/projects";

const STATUSES: Project["status"][] = ["Live", "Confirmed", "Upcoming", "Potential"];
const EVENTS: Project["event"][] = ["Airdrop", "Snapshot", "TGE", "Claim", "Points"];

export default function AirdropsExplorer({ items }: { items: Project[] }) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("All");
  const [chain, setChain] = useState("All");
  const [event, setEvent] = useState("All");

  const chains = useMemo(() => {
    const set = new Set(items.map((p) => p.chain).filter(Boolean));
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [items]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();

    return items.filter((p) => {
      if (status !== "All" && p.status !== status) return false;
      if (chain !== "All" && p.chain !== chain) return false;
      if (event !== "All" && p.event !== event) return false;

      if (q) {
        const haystack = `${p.name} ${p.symbol} ${p.chain}`.toLowerCase();
        if (!haystack.includes(q)) return false;
      }

      return true;
    });
  }, [items, search, status, chain, event]);

  return (
    <>
      <div className="filter-bar">
        <input
          placeholder="Search projects..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
        <select value={status} onChange={(e) => setStatus(e.target.value)}>
          <option value="All">All Statuses</option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
        <select value={chain} onChange={(e) => setChain(e.target.value)}>
          <option value="All">All Chains</option>
          {chains.map((c) => (
            <option key={c} value={c}>{c}</option>
          ))}
        </select>
        <select value={event} onChange={(e) => setEvent(e.target.value)}>
          <option value="All">All Events</option>
          {EVENTS.map((ev) => (
            <option key={ev} value={ev}>{ev}</option>
          ))}
        </select>
      </div>

      {filtered.length ? (
        <ProjectCards items={filtered} />
      ) : (
        <p className="muted" style={{ marginTop: 24 }}>
          No drops match your filters.
        </p>
      )}
    </>
  );
}
'@

$explorerDir = Join-Path $root "components"
if (-not (Test-Path $explorerDir)) { New-Item -ItemType Directory -Path $explorerDir | Out-Null }
$explorerPath = Join-Path $explorerDir "AirdropsExplorer.tsx"
[System.IO.File]::WriteAllText($explorerPath, $explorer, [System.Text.UTF8Encoding]::new($false))
Write-Host "Written: $explorerPath"

# 2) app/airdrops/page.tsx
$page = @'
import AirdropsExplorer from "@/components/AirdropsExplorer";
import { getProjects } from "@/lib/projects";

export const dynamic = "force-dynamic";
export const metadata = { title: "Airdrops" };

export default async function Airdrops() {
  const projects = await getProjects();

  return (
    <main className="page container">
      <div className="page-head">
        <div>
          <div className="section-kicker">DROP DISCOVERY</div>
          <h1>Crypto Airdrops</h1>
          <p>Upcoming, live and potential drops tracked automatically from multiple sources.</p>
        </div>
      </div>

      <AirdropsExplorer items={projects} />
    </main>
  );
}
'@

$pagePath = Join-Path $root "app\airdrops\page.tsx"
[System.IO.File]::WriteAllText($pagePath, $page, [System.Text.UTF8Encoding]::new($false))
Write-Host "Written: $pagePath"

# 3) globals.css: add "select" to .filter-bar input/button rule
$cssPath = Join-Path $root "app\globals.css"
$css = Get-Content $cssPath -Raw -Encoding UTF8

$old = '.filter-bar input,.filter-bar button{'
$new = '.filter-bar input,.filter-bar button,.filter-bar select{cursor:pointer;'

if ($css.Contains($old)) {
    $css = $css.Replace($old, $new)
    [System.IO.File]::WriteAllText($cssPath, $css, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated: $cssPath (added select styling)"
} else {
    Write-Host "WARNING: expected CSS rule not found in $cssPath - skipped CSS update, check manually."
}

Write-Host ""
Write-Host "Done. Restart the dev server if needed and hard-refresh /airdrops."
