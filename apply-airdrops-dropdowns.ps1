$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
Set-Location $root

Write-Host "Working in: $root"

# 1) components/AirdropsExplorer.tsx (custom styled dropdowns instead of native <select>)
$explorer = @'
"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";
import ProjectCards from "@/components/ProjectCards";
import { Project } from "@/data/projects";

const STATUSES: Project["status"][] = ["Live", "Confirmed", "Upcoming", "Potential"];
const EVENTS: Project["event"][] = ["Airdrop", "Snapshot", "TGE", "Claim", "Points"];

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
        {value === "All" ? label : value}
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

# 2) globals.css: revert select-specific rule (no longer needed) and add custom dropdown styles
$cssPath = Join-Path $root "app\globals.css"
$css = Get-Content $cssPath -Raw -Encoding UTF8

$oldSelectRule = '.filter-bar input,.filter-bar button,.filter-bar select{cursor:pointer;'
$restoredRule = '.filter-bar input,.filter-bar button{'

if ($css.Contains($oldSelectRule)) {
    $css = $css.Replace($oldSelectRule, $restoredRule)
    Write-Host "Reverted native-select tweak in .filter-bar rule."
} else {
    Write-Host "Note: previous select tweak not found (may already be clean) - continuing."
}

$dropdownCss = @'

.filter-dropdown{position:relative}
.filter-dropdown-btn{background:rgba(255,255,255,.035);border:1px solid rgba(255,255,255,.1);color:#8d98a8;border-radius:10px;padding:11px 13px;display:inline-flex;align-items:center;gap:8px;cursor:pointer;white-space:nowrap;font-size:13px;font-family:inherit;transition:.2s ease}
.filter-dropdown-btn:hover{background:rgba(255,255,255,.07);border-color:rgba(255,255,255,.2);color:#eef2f8}
.filter-dropdown-btn svg{color:#69748a;transition:transform .2s ease}
.filter-dropdown-btn.open{background:rgba(255,255,255,.07);border-color:rgba(255,255,255,.2);color:#eef2f8}
.filter-dropdown-btn.open svg{transform:rotate(180deg)}
.filter-dropdown-panel{position:absolute;top:calc(100% + 8px);left:0;min-width:190px;max-height:280px;overflow-y:auto;padding:6px;border:1px solid rgba(255,255,255,.11);background:rgba(21,24,29,.97);backdrop-filter:blur(24px);border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.55);z-index:40;display:flex;flex-direction:column;gap:2px}
.filter-dropdown-panel button{display:block;width:100%;text-align:left;padding:8px 10px;border-radius:8px;background:none;border:0;color:#b9bec8;font-size:13px;font-weight:600;font-family:inherit;cursor:pointer}
.filter-dropdown-panel button:hover{background:rgba(255,255,255,.07);color:#fff}
.filter-dropdown-panel button.active{color:#7ec8ff;background:rgba(126,200,255,.08)}
@media(max-width:760px){.filter-dropdown-panel{left:auto;right:0}}
'@

if (-not $css.Contains(".filter-dropdown{")) {
    $css = $css + $dropdownCss
    Write-Host "Appended custom dropdown styles."
} else {
    Write-Host "Custom dropdown styles already present - skipped append."
}

[System.IO.File]::WriteAllText($cssPath, $css, [System.Text.UTF8Encoding]::new($false))
Write-Host "Updated: $cssPath"

Write-Host ""
Write-Host "Done. Restart the dev server if needed and hard-refresh /airdrops."
