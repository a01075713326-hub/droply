import type { Metadata } from "next";
import Link from "next/link";
import { ArrowRight, Zap } from "lucide-react";
import { getProjects } from "@/lib/projects";
import ProjectTable from "@/components/ProjectTable";
import CalendarCard from "@/components/CalendarCard";
import DroplyMark from "@/components/DroplyMark";
import { getHubLinks, getChainHubs, slugify } from "@/lib/hubs";
import { getNearestReward, getHotActivities } from "@/lib/highlights";
import { NearestRewardCard, HotActivitiesCard } from "@/components/HomeHighlights";

export const dynamic = "force-dynamic";

export default async function Home() {
  const projects = await getProjects();
  const nearestReward = getNearestReward(projects);
  const hotActivities = getHotActivities(projects);
  const live = projects.filter((p) => p.status === "Live" || p.isLive === true).length;
  const week = projects.filter((p) => p.date && p.date >= new Date().toISOString().slice(0, 10)).length;
  const hubLinks = getHubLinks(projects);
  const chainSlugs = new Set(getChainHubs(projects).map((h) => h.slug));
  const netHref = (name: string) => chainSlugs.has(slugify(name)) ? `/chain/${slugify(name)}` : `/airdrops?chain=${name}`;
  return <main>
    <section className="hero container">
      <div className="hero-copy">
        <div className="eyebrow"><span className="pulse-dot"/> The crypto drop tracker</div>
        <h1>Track what's<br/><em>dropping.</em></h1>
        <p>Discover upcoming airdrops, snapshots,<br className="desktop"/> TGE and token claims. All in one place.</p>
        <div className="hero-actions"><Link href="/airdrops" className="primary-btn">Explore drops <ArrowRight size={16}/></Link><Link href="/calendar" className="glass-btn">View calendar</Link></div>
        <div className="stats"><div><b>{projects.length.toLocaleString()}</b><span>Tracked Drops</span></div><div><b>{week.toLocaleString()}</b><span>Upcoming</span></div><div><b>{live.toLocaleString()}</b><span>Live Drops</span></div></div>
      </div>
      <div className="hero-orb" aria-hidden="true">
        <svg className="hero-graph" viewBox="0 0 400 380" fill="none">
          <defs>
            <linearGradient id="graphLine" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#22d3ee"/>
              <stop offset="50%" stopColor="#4361ee"/>
              <stop offset="100%" stopColor="#d946ef"/>
            </linearGradient>
          </defs>
          <g stroke="url(#graphLine)" strokeWidth="1.2" opacity="0.55">
            <line x1="200" y1="190" x2="40" y2="60"/>
            <line x1="200" y1="190" x2="330" y2="55"/>
            <line x1="200" y1="190" x2="30" y2="240"/>
            <line x1="200" y1="190" x2="350" y2="255"/>
            <line x1="200" y1="190" x2="200" y2="330"/>
          </g>
          <circle cx="40" cy="60" r="4" fill="#22d3ee"/>
          <circle cx="330" cy="55" r="4" fill="#4361ee"/>
          <circle cx="30" cy="240" r="4" fill="#8b5cf6"/>
          <circle cx="350" cy="255" r="4" fill="#d946ef"/>
          <circle cx="200" cy="330" r="4" fill="#4361ee"/>
        </svg>
        <img src="/droplet-logo.png" alt="" className="hero-logo-img"/>
      </div>
      <div className="hero-side">
        {nearestReward ? <NearestRewardCard project={nearestReward}/> : null}
        {hotActivities.length ? <HotActivitiesCard projects={hotActivities}/> : null}
        <div className="glass-card newsletter"><h3>Never miss a drop.</h3><p>Get the latest updates and verified information directly in your inbox.</p><div className="email-box"><input placeholder="Your email address"/><button>&rarr;</button></div><div className="quick-links">{[["Airdrops","/airdrops"],["TGE","/calendar"],["Snapshots","/calendar"],["Claims","/airdrops?event=claim"]].map(([x,y])=><Link href={y} key={x}><span>&#9675;</span>{x}</Link>)}</div></div>
        <CalendarCard/>
      </div>
    </section>
    <section className="container"><div className="networks"><div className="section-kicker"><span>&#9670;</span> TOP NETWORKS</div><div className="network-marquee"><div className="network-track">{[...["Base","Ethereum","Solana","Arbitrum","Aptos","TON"],...["Base","Ethereum","Solana","Arbitrum","Aptos","TON"]].map((x,i)=><Link href={netHref(x)} className="network-card" key={x+i}><img src={`https://icons.llamao.fi/icons/chains/rsz_${x.toLowerCase()}.jpg`} alt={x} className="chain-icon-img"/><div><b>{x}</b><small>Explore projects</small></div><ArrowRight size={14}/></Link>)}</div></div></div></section>
    {hubLinks.length > 0 ? <section className="container">
      <div className="section-heading"><div><div className="section-kicker"><span>&#9670;</span> AIRDROP LISTS</div><h2>Browse by type.</h2></div><Link href="/airdrops">View all &rarr;</Link></div>
      <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
        {hubLinks.map((h) => <Link className="type-pill" href={h.href} key={h.href}>{h.label} ({h.count})</Link>)}
      </div>
    </section> : null}
    <section className="container content-grid"><div><div className="section-heading"><div><div className="section-kicker"><Zap size={16}/> LATEST DROPS</div><h2>What's happening next.</h2></div><Link href="/airdrops">View all &rarr;</Link></div><ProjectTable items={projects.slice(0, 12)}/></div></section>
  </main>;
}

export const metadata: Metadata = {
  alternates: { canonical: "/" },
};
