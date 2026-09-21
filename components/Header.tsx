import Link from "next/link";
import { ChevronDown } from "lucide-react";
import DroplyMark from "./DroplyMark";
import HeaderSearch from "./HeaderSearch";
import MobileNav from "./MobileNav";
import ChainIcon from "./ChainIcon";
import { getProjects } from "@/lib/projects";
import type { Project } from "@/data/projects";
import { getChainHubs, slugify, type Hub } from "@/lib/hubs";

export default async function Header() {
  const all = (await Promise.resolve(getProjects())) as unknown as Array<Record<string, unknown>>;
  const items = all
    .map((p) => ({
      name: String(p.name ?? ""),
      slug: String(p.slug ?? ""),
      chain: String(p.chain ?? ""),
      logo: String(p.logo ?? ""),
    }))
    .filter((x) => x.name && x.slug);

  // BY BLOCKCHAIN menu: preferred chains first, only those that have a hub page.
  const PREFERRED_CHAINS = ["Base", "Solana", "Ethereum", "Arbitrum", "Hyperliquid", "Aptos", "Sui", "TON", "ZKsync", "Blast"];
  const chainHubs = getChainHubs(all as unknown as Project[]);
  const menuChains = PREFERRED_CHAINS
    .map((name) => chainHubs.find((h) => h.slug === slugify(name)))
    .filter((h): h is Hub => Boolean(h));
  for (const h of chainHubs) {
    if (menuChains.length >= 10) break;
    if (!menuChains.some((m) => m.slug === h.slug)) menuChains.push(h);
  }

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
            <Link href="/airdrops/live">&#9679; Live Airdrops</Link>
            <Link href="/airdrops?event=claim">&#10003; Claims</Link>
            <div className="divider"/>
            <div className="drop-group-label">BY BLOCKCHAIN</div>
            {menuChains.map((hub) =>
              <Link href={`/chain/${hub.slug}`} key={hub.slug}><span style={{ display: "inline-flex", alignItems: "center", gap: 8 }}><ChainIcon slug={hub.slug} name={hub.name} size={16} />{hub.name}</span></Link>
            )}
            <Link href="/airdrops" className="show-all">&#8599; Show all</Link>
          </div>
        </div>
        <Link href="/calendar">Calendar</Link>
        <Link href="/favorites">Favorites</Link>
        <Link href="/stats">Stats</Link>
        <Link href="/feed">Feed</Link>
        <Link href="/airdrops">Projects</Link>
      </nav>
      <div className="header-actions">
        <HeaderSearch items={items} />
        <MobileNav chains={menuChains.map((h) => ({ slug: h.slug, name: h.name }))} />
      </div>
    </header>
  );
}