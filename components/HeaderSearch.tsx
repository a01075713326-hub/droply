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