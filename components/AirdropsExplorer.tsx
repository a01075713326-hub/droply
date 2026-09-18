"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import { ChevronDown } from "lucide-react";
import ProjectCards from "@/components/ProjectCards";
import { Project } from "@/data/projects";

const STATUSES: Project["status"][] = ["Live", "Confirmed", "Upcoming", "Potential"];
const EVENTS: Project["event"][] = ["Airdrop"];

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
  className,
}: {
  label: string;
  value: string;
  options: string[];
  onChange: (value: string) => void;
  className?: string;
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
    <div className={`filter-dropdown${className ? ` ${className}` : ""}`} ref={ref}>
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
      if (status !== "All") {
        const isLiveNow = p.status === "Live" || p.isLive === true;
        if (status === "Live" ? !isLiveNow : p.status !== status) return false;
      }
      if (chain !== "All" && !splitChains(p.chain).includes(chain)) return false;
      if (event !== "All" && !splitChains(p.event).includes(event)) return false;

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
        <FilterDropdown
          label="All Chains"
          value={chain}
          options={chains}
          onChange={setChain}
          className="chains-dropdown"
        />
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

