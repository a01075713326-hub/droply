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
        <Link href="/feed" onClick={close}>Feed</Link>
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