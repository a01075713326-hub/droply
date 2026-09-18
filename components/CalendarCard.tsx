"use client";

import { useMemo, useState } from "react";
import Link from "next/link";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { projects } from "@/data/projects";
import { initials } from "@/lib/projects";
import FavoriteButton from "@/components/FavoriteButton";

const chainLogos: Record<string, string> = {
  Base: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/base/info/logo.png",
  Ethereum: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/ethereum/info/logo.png",
  Solana: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/solana/info/logo.png",
  Arbitrum: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/arbitrum/info/logo.png",
  Aptos: "https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/aptos/info/logo.png"
};

const MONTH_NAMES = ["January","February","March","April","May","June","July","August","September","October","November","December"];
const WEEKDAYS = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"];

function pad(n: number) { return n < 10 ? `0${n}` : `${n}`; }

function toIso(dateStr?: string): string | null {
  if (!dateStr) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) return dateStr;
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return null;
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

function buildGrid(year: number, month: number) {
  const first = new Date(year, month, 1);
  const startOffset = (first.getDay() + 6) % 7; // Mon=0
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cells: { key: string; label: string; iso: string | null }[] = [];
  for (let i = 0; i < startOffset; i++) cells.push({ key: `pre-${i}`, label: "", iso: null });
  for (let d = 1; d <= daysInMonth; d++) {
    cells.push({ key: `d-${d}`, label: String(d), iso: `${year}-${pad(month + 1)}-${pad(d)}` });
  }
  while (cells.length % 7 !== 0) cells.push({ key: `post-${cells.length}`, label: "", iso: null });
  return cells;
}

export default function CalendarCard() {
  const today = new Date();
  const [year, setYear] = useState(today.getFullYear());
  const [month, setMonth] = useState(today.getMonth());
  const todayIso = `${today.getFullYear()}-${pad(today.getMonth() + 1)}-${pad(today.getDate())}`;
  const [selected, setSelected] = useState(todayIso);

  const eventDates = useMemo(() => new Set(projects.map((p) => toIso(p.date)).filter(Boolean) as string[]), []);
  const cells = useMemo(() => buildGrid(year, month), [year, month]);
  const selectedEvents = useMemo(() => projects.filter((p) => toIso(p.date) === selected), [selected]);

  function prevMonth() {
    if (month === 0) { setMonth(11); setYear((y) => y - 1); } else { setMonth((m) => m - 1); }
  }
  function nextMonth() {
    if (month === 11) { setMonth(0); setYear((y) => y + 1); } else { setMonth((m) => m + 1); }
  }

  return <aside className="side-stack">
    <section className="glass-card calendar-card">
      <div className="card-title"><div><h3>{MONTH_NAMES[month]} {year}</h3></div><div className="calendar-nav"><button type="button" onClick={prevMonth}><ChevronLeft size={15}/></button><button type="button" onClick={nextMonth}><ChevronRight size={15}/></button></div></div>
      <div className="weekdays">{WEEKDAYS.map(x=><span key={x}>{x}</span>)}</div>
      <div className="calendar-grid">
        {cells.map((c) => c.iso ? (
          <button
            type="button"
            key={c.key}
            className={`day ${selected === c.iso ? "selected" : ""} ${eventDates.has(c.iso) ? "has-event" : ""}`}
            onClick={() => setSelected(c.iso as string)}
          >
            {c.label}{eventDates.has(c.iso) && <i/>}
          </button>
        ) : <span key={c.key} className="day empty"/>)}
      </div>
      <div className="calendar-events">
        <div className="event-date"><b>{new Date(selected + "T00:00:00").toLocaleDateString("en-US",{month:"short",day:"numeric",year:"numeric"})}</b><span>{selectedEvents.length} event{selectedEvents.length === 1 ? "" : "s"}</span></div>
        {selectedEvents.length ? selectedEvents.slice(0,4).map(p=><Link href={`/project/${p.slug}`} className="mini-event" key={p.id}><div className="mini-icon">{p.logo ? <img src={p.logo} alt={p.name} className="mini-icon-img"/> : initials(p.name)}</div><div><strong>{p.name}</strong><small>{p.event}</small></div><span>{p.chain}</span><FavoriteButton slug={p.slug} /></Link>) : <p className="muted" style={{padding:"6px 0",fontSize:12}}>No events on this day.</p>}
        <Link href="/calendar" className="text-link">View all events &rarr;</Link>
      </div>
    </section>
    <section className="glass-card calendar-card">
      <div className="card-title"><h3>Trending Chains</h3><Link href="/airdrops">View all &rarr;</Link></div>
      {["Base","Ethereum","Solana","Arbitrum","Aptos"].map((c,i)=><Link className="chain-row" href={`/airdrops?chain=${c}`} key={c}><span className="chain-icon">{chainLogos[c] ? <img src={chainLogos[c]} alt={c} className="chain-icon-img"/> : c[0]}</span><span>{c}</span><small>{[512,438,376,221,154][i]} projects</small><ChevronRight size={15}/></Link>)}
    </section>
  </aside>
}