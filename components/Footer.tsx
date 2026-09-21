import Link from "next/link";
import { getProjects } from "@/lib/projects";
import { getHubLinks } from "@/lib/hubs";

export default async function Footer() {
  const hubLinks = getHubLinks(await getProjects());
  return (
    <footer className="site-footer">
      <div className="site-footer__inner container">
        <div className="site-footer__brand">
          <strong>Droply</strong>
          <p>
            Crypto airdrop tracker. Data is collected from public sources and may be incomplete or
            out of date. Nothing on this site is financial advice.
          </p>
        </div>
        {hubLinks.length > 0 ? (
          <nav className="site-footer__nav" aria-label="Airdrop lists">
            {hubLinks.map((h) => (
              <Link href={h.href} key={h.href}>{h.label}</Link>
            ))}
          </nav>
        ) : null}
        <nav className="site-footer__nav" aria-label="Footer">
          <Link href="/about">About</Link>
          <Link href="/contact">Contact</Link>
          <Link href="/disclaimer">Disclaimer</Link>
          <Link href="/privacy">Privacy</Link>
        </nav>
      </div>
      <div className="site-footer__bottom container">
        &copy; {new Date().getFullYear()} Droply. Data sources: CryptoRank, Airdrops.io, AirdropAlert.
      </div>
    </footer>
  );
}