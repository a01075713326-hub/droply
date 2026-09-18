$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
Set-Location $root

Write-Host "Working in: $root"

# 1) components/AirdropsExplorer.tsx - split comma-separated chain values
$explorer = @'
"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";
import ProjectCards from "@/components/ProjectCards";
import { Project } from "@/data/projects";

const STATUSES: Project["status"][] = ["Live", "Confirmed", "Upcoming", "Potential"];
const EVENTS: Project["event"][] = ["Airdrop", "Snapshot", "TGE", "Claim", "Points"];

function splitChains(value: string): string[] {
  return value
    .split(",")
    .map((c) => c.trim())
    .filter(Boolean);
}

function FilterDropdown({
  label,
  value,
  options,
  onChange,
}: {
  label: string;
  value: string;
  options: string[];
  onChange: (value: string) => void;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function onDocClick(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", onDocClick);
    return () => document.removeEventListener("mousedown", onDocClick);
  }, []);

  const select = (v: string) => {
    onChange(v);
    setOpen(false);
  };

  return (
    <div className="filter-dropdown" ref={ref}>
      <button
        type="button"
        className={`filter-dropdown-btn${open ? " open" : ""}`}
        onClick={() => setOpen((o) => !o)}
      >
        <span className="filter-dropdown-label">{value === "All" ? label : value}</span>
        <ChevronDown size={14} />
      </button>
      {open ? (
        <div className="filter-dropdown-panel">
          <button
            type="button"
            className={value === "All" ? "active" : ""}
            onClick={() => select("All")}
          >
            {label}
          </button>
          {options.map((opt) => (
            <button
              key={opt}
              type="button"
              className={value === opt ? "active" : ""}
              onClick={() => select(opt)}
              title={opt}
            >
              {opt}
            </button>
          ))}
        </div>
      ) : null}
    </div>
  );
}

export default function AirdropsExplorer({ items }: { items: Project[] }) {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("All");
  const [chain, setChain] = useState("All");
  const [event, setEvent] = useState("All");

  const chains = useMemo(() => {
    const set = new Set<string>();
    items.forEach((p) => {
      splitChains(p.chain).forEach((c) => set.add(c));
    });
    return Array.from(set).sort((a, b) => a.localeCompare(b));
  }, [items]);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();

    return items.filter((p) => {
      if (status !== "All" && p.status !== status) return false;
      if (chain !== "All" && !splitChains(p.chain).includes(chain)) return false;
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
        <FilterDropdown label="All Statuses" value={status} options={STATUSES} onChange={setStatus} />
        <FilterDropdown label="All Chains" value={chain} options={chains} onChange={setChain} />
        <FilterDropdown label="All Events" value={event} options={EVENTS} onChange={setEvent} />
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

$explorerPath = Join-Path $root "components\AirdropsExplorer.tsx"
[System.IO.File]::WriteAllText($explorerPath, $explorer, [System.Text.UTF8Encoding]::new($false))
Write-Host "Written: $explorerPath"

# 2) globals.css - cap dropdown width, add ellipsis, cap trigger button label width too
$cssPath = Join-Path $root "app\globals.css"
$css = Get-Content $cssPath -Raw -Encoding UTF8

$oldPanel = '.filter-dropdown-panel{position:absolute;top:calc(100% + 8px);left:0;min-width:190px;max-height:280px;overflow-y:auto;padding:6px;border:1px solid rgba(255,255,255,.11);background:rgba(21,24,29,.97);backdrop-filter:blur(24px);border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.55);z-index:40;display:flex;flex-direction:column;gap:2px}'
$newPanel = '.filter-dropdown-panel{position:absolute;top:calc(100% + 8px);left:0;width:230px;max-height:280px;overflow-y:auto;padding:6px;border:1px solid rgba(255,255,255,.11);background:rgba(21,24,29,.97);backdrop-filter:blur(24px);border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.55);z-index:40;display:flex;flex-direction:column;gap:2px}'

if ($css.Contains($oldPanel)) {
    $css = $css.Replace($oldPanel, $newPanel)
    Write-Host "Fixed dropdown panel width (190px min -> 230px fixed)."
} else {
    Write-Host "WARNING: .filter-dropdown-panel rule not found as expected - skipped that replace, check manually."
}

$oldPanelBtn = '.filter-dropdown-panel button{display:block;width:100%;text-align:left;padding:8px 10px;border-radius:8px;background:none;border:0;color:#b9bec8;font-size:13px;font-weight:600;font-family:inherit;cursor:pointer}'
$newPanelBtn = '.filter-dropdown-panel button{display:block;width:100%;text-align:left;padding:8px 10px;border-radius:8px;background:none;border:0;color:#b9bec8;font-size:13px;font-weight:600;font-family:inherit;cursor:pointer;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'

if ($css.Contains($oldPanelBtn)) {
    $css = $css.Replace($oldPanelBtn, $newPanelBtn)
    Write-Host "Added ellipsis truncation to dropdown options."
} else {
    Write-Host "WARNING: .filter-dropdown-panel button rule not found as expected - skipped that replace, check manually."
}

# Cap the trigger button's own label width too, so a long selected chain name doesn't stretch the bar
if (-not $css.Contains(".filter-dropdown-label{")) {
    $css = $css + "`n.filter-dropdown-label{max-width:150px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}`n"
    Write-Host "Added .filter-dropdown-label truncation rule."
} else {
    Write-Host ".filter-dropdown-label rule already present - skipped."
}

[System.IO.File]::WriteAllText($cssPath, $css, [System.Text.UTF8Encoding]::new($false))
Write-Host "Updated: $cssPath"

Write-Host ""
Write-Host "Done. Restart the dev server if needed and hard-refresh /airdrops."
