"use client";

import { useState } from "react";
import {
  Globe,
  Gift,
  BookOpen,
  FileText,
  Link2,
  Send,
  MessageCircle,
  Copy,
  Check,
} from "lucide-react";

export type PanelLink = {
  kind:
    | "website"
    | "claim"
    | "docs"
    | "whitepaper"
    | "x"
    | "telegram"
    | "discord";
  title: string;
  url: string;
};

const ICONS = {
  website: Globe,
  claim: Gift,
  docs: BookOpen,
  whitepaper: FileText,
  x: XIcon,
  telegram: Send,
  discord: MessageCircle,
} as const;

/** lucide has no X/Twitter glyph, so this is the official mark as a path. */
function XIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
    </svg>
  );
}

function shortUrl(url: string) {
  try {
    const u = new URL(url);
    const path = u.pathname === "/" ? "" : u.pathname;
    return u.host.replace(/^www\./, "") + path;
  } catch {
    return url;
  }
}

function Row({ link }: { link: PanelLink }) {
  const [copied, setCopied] = useState(false);
  const Icon = ICONS[link.kind];

  async function copy() {
    try {
      await navigator.clipboard.writeText(link.url);
      setCopied(true);
      setTimeout(() => setCopied(false), 1400);
    } catch {
      /* clipboard blocked -- the row is still a working link */
    }
  }

  return (
    <div className="link-row">
      <a
        href={link.url}
        target="_blank"
        rel="noreferrer"
        className="link-row-main"
      >
        <span className="link-row-icon">
          <Icon size={16} />
        </span>
        <span className="link-row-text">
          <b>{link.title}</b>
          <small>{shortUrl(link.url)}</small>
        </span>
      </a>
      <button
        type="button"
        onClick={copy}
        className="link-copy"
        aria-label={`Copy ${link.title} link`}
      >
        {copied ? <Check size={15} /> : <Copy size={15} />}
      </button>
    </div>
  );
}

export default function LinksPanel({
  official,
  social,
}: {
  official: PanelLink[];
  social: PanelLink[];
}) {
  if (!official.length && !social.length) return null;

  return (
    <div className="links-panel">
      <h2 className="links-panel-title">Links</h2>

      {official.length > 0 && (
        <div className="links-group">
          <div className="section-kicker">
            <Link2 size={13} /> OFFICIAL LINKS
          </div>
          {official.map((l) => (
            <Row key={l.url + l.kind} link={l} />
          ))}
        </div>
      )}

      {social.length > 0 && (
        <div className="links-group">
          <div className="section-kicker">
            <Link2 size={13} /> SOCIAL LINKS
          </div>
          {social.map((l) => (
            <Row key={l.url + l.kind} link={l} />
          ))}
        </div>
      )}
    </div>
  );
}
