# redesign-cryptorank-10.ps1 (trust pages + footer)
# Run from the project root:
#   powershell -ExecutionPolicy Bypass -File .\redesign-cryptorank-10.ps1
# Optional: pass the contact directly
#   powershell -ExecutionPolicy Bypass -File .\redesign-cryptorank-10.ps1 -Email you@example.com -Telegram yourname
#
# Creates:  lib\site.ts, components\Footer.tsx,
#           app\about\page.tsx, app\contact\page.tsx, app\disclaimer\page.tsx, app\privacy\page.tsx
# Patches:  app\layout.tsx (adds <Footer/>), app\sitemap.ts (adds the 4 pages), app\globals.css (styles)
# Existing files are never overwritten (a "skipped" message is shown instead).
# Backups: *.bak-redesign10
# NOTE: ASCII-only on purpose. Read the texts once: they must match what your site really does.

param(
  [string]$Email = '',
  [string]$Telegram = ''
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)

if (-not (Test-Path -LiteralPath '.\app\layout.tsx')) {
  Write-Host 'app\layout.tsx not found. Run this from the project root.' -ForegroundColor Red
  exit 1
}

# ---------- contact ----------
if (-not $Email -and -not $Telegram) {
  Write-Host 'Public contact for the Contact page (visible to everyone). Fill at least one.' -ForegroundColor Cyan
  $Email = Read-Host 'Email (Enter to skip)'
  $Telegram = Read-Host 'Telegram username, e.g. droply_support (Enter to skip)'
}

$Email = $Email.Trim()
$Telegram = ($Telegram.Trim() -replace '^(https?://)?(t\.me/)?@?', '')

if ($Email -and $Email -notmatch '^[^@\s"''<>]+@[^@\s"''<>]+\.[^@\s"''<>]+$') {
  Write-Host "Email looks invalid: $Email" -ForegroundColor Red
  exit 1
}
if ($Telegram -and $Telegram -notmatch '^[A-Za-z0-9_]{4,32}$') {
  Write-Host "Telegram username looks invalid: $Telegram" -ForegroundColor Red
  exit 1
}
if (-not $Email -and -not $Telegram) {
  Write-Host 'No contact given. A Contact page without a contact is useless, so nothing was changed.' -ForegroundColor Red
  exit 1
}

$today = (Get-Date).ToString('MMMM d, yyyy', [System.Globalization.CultureInfo]::InvariantCulture)

function WriteNew([string]$rel, [string]$content) {
  $full = Join-Path (Get-Location) $rel
  if (Test-Path -LiteralPath $full) {
    Write-Host "skipped (already exists): $rel" -ForegroundColor Yellow
    return
  }
  $dir = Split-Path -Parent $full
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  [System.IO.File]::WriteAllText($full, $content, $utf8)
  Write-Host "created: $rel" -ForegroundColor Green
}

function Patch([string]$text, [string]$old, [string]$new, [string]$label) {
  $n = [regex]::Matches($text, [regex]::Escape($old)).Count
  if ($n -ne 1) {
    Write-Host "NOT FOUND (or more than one match): $label (found: $n)" -ForegroundColor Yellow
    return $null
  }
  return $text.Replace($old, $new)
}

# ---------- lib\site.ts ----------
$site = @'
export const SITE = {
  name: "Droply",
  url: "https://droply.digital",
  email: "__EMAIL__",
  telegram: "__TELEGRAM__",
  updated: "__UPDATED__",
};
'@
$site = $site.Replace('__EMAIL__', $Email).Replace('__TELEGRAM__', $Telegram).Replace('__UPDATED__', $today)
WriteNew 'lib\site.ts' $site

# ---------- components\Footer.tsx ----------
$footer = @'
import Link from "next/link";

export default function Footer() {
  return (
    <footer className="site-footer">
      <div className="site-footer__inner">
        <div className="site-footer__brand">
          <strong>Droply</strong>
          <p>
            Crypto airdrop tracker. Data is collected from public sources and may be incomplete or
            out of date. Nothing on this site is financial advice.
          </p>
        </div>
        <nav className="site-footer__nav" aria-label="Footer">
          <Link href="/about">About</Link>
          <Link href="/contact">Contact</Link>
          <Link href="/disclaimer">Disclaimer</Link>
          <Link href="/privacy">Privacy</Link>
        </nav>
      </div>
      <div className="site-footer__bottom">
        &copy; {new Date().getFullYear()} Droply. Data sources: CryptoRank, Airdrops.io, AirdropAlert.
      </div>
    </footer>
  );
}
'@
WriteNew 'components\Footer.tsx' $footer

# ---------- app\about\page.tsx ----------
$about = @'
import type { Metadata } from "next";
import Link from "next/link";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "About",
  description: "What Droply is, where its airdrop data comes from and how projects are checked.",
  alternates: { canonical: "/about" },
};

export default function AboutPage() {
  return (
    <main className="page container legal-page">
      <article className="article-card legal-card">
        <h1>About Droply</h1>
        <p>
          Droply is a crypto airdrop tracker. It collects airdrop and points campaigns from public
          sources and puts the main facts in one place: status, chain, estimated cost to farm,
          deadlines and step-by-step tasks.
        </p>

        <h2>Where the data comes from</h2>
        <p>
          Project data is gathered automatically from public sources, currently CryptoRank,
          Airdrops.io and AirdropAlert. Each project page names its source and links back to it.
          Data can change or lag behind the source, so always confirm important details on the
          official channels of the project.
        </p>

        <h2>How projects are checked</h2>
        <p>
          For many projects we run automated checks: whether the official website is reachable,
          whether social links are confirmed by the official site, and whether a contract address
          and a public audit exist. The result is shown as a risk level together with the full list
          of rules, so you can see why a project got its score. The score is a screening aid, not a
          verdict, and a low score does not mean a project is safe.
        </p>

        <h2>What is reviewed by hand</h2>
        <p>
          Selected projects also have our own overview, risks and notes. Those sections are marked
          Our take and show the date of the last review. Everything else on a project page is
          compiled automatically.
        </p>

        <h2>Links and independence</h2>
        <p>
          If we use affiliate or referral links, they are labelled as sponsored and they do not
          change how a project is scored.
        </p>

        <h2>Corrections</h2>
        <p>
          Found a mistake, or represent a project and want something fixed? Use the{" "}
          <Link href="/contact">contact page</Link>.
        </p>

        <p className="legal-updated">Last updated: {SITE.updated}</p>
      </article>
    </main>
  );
}
'@
WriteNew 'app\about\page.tsx' $about

# ---------- app\contact\page.tsx ----------
$contact = @'
import type { Metadata } from "next";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Contact",
  description: "How to contact Droply: corrections, project owners, partnerships.",
  alternates: { canonical: "/contact" },
};

export default function ContactPage() {
  return (
    <main className="page container legal-page">
      <article className="article-card legal-card">
        <h1>Contact</h1>
        <p>Use these channels to:</p>
        <ul>
          <li>report a mistake or an outdated detail on a project page;</li>
          <li>request a correction or removal if you represent a project;</li>
          <li>ask about partnerships.</li>
        </ul>

        <h2>Where to write</h2>
        <ul>
          {SITE.email ? (
            <li>
              Email: <a href={`mailto:${SITE.email}`}>{SITE.email}</a>
            </li>
          ) : null}
          {SITE.telegram ? (
            <li>
              Telegram:{" "}
              <a href={`https://t.me/${SITE.telegram}`} target="_blank" rel="noreferrer">
                @{SITE.telegram}
              </a>
            </li>
          ) : null}
        </ul>

        <h2>Please note</h2>
        <p>
          We cannot give investment advice or recover lost funds. We will never ask for your seed
          phrase or private keys. If someone asks for them in our name, it is a scam.
        </p>

        <p className="legal-updated">Last updated: {SITE.updated}</p>
      </article>
    </main>
  );
}
'@
WriteNew 'app\contact\page.tsx' $contact

# ---------- app\disclaimer\page.tsx ----------
$disclaimer = @'
import type { Metadata } from "next";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Disclaimer",
  description: "Droply is not financial advice. Airdrops are speculative and data may be outdated.",
  alternates: { canonical: "/disclaimer" },
};

export default function DisclaimerPage() {
  return (
    <main className="page container legal-page">
      <article className="article-card legal-card">
        <h1>Disclaimer</h1>

        <h2>Not financial advice</h2>
        <p>
          Everything on Droply is provided for information only. It is not financial, investment,
          legal or tax advice, and it is not a recommendation to take part in any project. You are
          responsible for your own decisions.
        </p>

        <h2>Airdrops are speculative</h2>
        <p>
          A listed airdrop, points programme or campaign does not guarantee a token, a reward or any
          value. Points are not tokens, and projects can change or cancel their plans at any time.
          Farming can cost money in fees and time, and you can lose funds.
        </p>

        <h2>Scams and wallet safety</h2>
        <ul>
          <li>Never share your seed phrase or private keys with anyone.</li>
          <li>Reach a project only through links you have confirmed on its official channels.</li>
          <li>Read what a transaction does before you sign it, and be careful with token approvals.</li>
          <li>Use a separate wallet for experiments when you can.</li>
        </ul>

        <h2>Data may be wrong or outdated</h2>
        <p>
          Data is collected automatically from public sources and may be incomplete, delayed or
          incorrect. Dates, requirements and rewards can change without notice. Always confirm
          details with the official sources of the project.
        </p>

        <h2>Automated risk level</h2>
        <p>
          The verification block and risk level on project pages come from automated checks of
          public data. They can miss problems, and a low score does not mean a project is safe.
        </p>

        <h2>Third-party links</h2>
        <p>
          Droply links to websites we do not control. We are not responsible for their content or
          for what happens when you use them. Links labelled as sponsored may earn us a commission.
        </p>

        <h2>Liability</h2>
        <p>
          You use Droply at your own risk. To the extent permitted by law, we are not liable for
          losses that result from using the information on this site.
        </p>

        <p className="legal-updated">Last updated: {SITE.updated}</p>
      </article>
    </main>
  );
}
'@
WriteNew 'app\disclaimer\page.tsx' $disclaimer

# ---------- app\privacy\page.tsx ----------
$privacy = @'
import type { Metadata } from "next";
import Link from "next/link";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "What data Droply handles when you visit the site.",
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  return (
    <main className="page container legal-page">
      <article className="article-card legal-card">
        <h1>Privacy Policy</h1>
        <p>
          This page explains what data Droply handles when you use droply.digital. We keep it to a
          minimum.
        </p>

        <h2>What we handle</h2>
        <ul>
          <li>
            There are no user accounts, and the site does not ask you to submit personal data.
          </li>
          <li>
            Favorites you save are stored in your own browser (local storage) on your device. We do
            not receive them.
          </li>
          <li>
            Like most websites, our hosting infrastructure may process technical data such as IP
            address, browser type and requested pages in server logs, for security and to keep the
            site running.
          </li>
        </ul>

        <h2>Analytics and cookies</h2>
        <p>
          At the moment Droply does not use advertising or analytics cookies. If we add analytics or
          any tracking, we will describe it on this page.
        </p>

        <h2>External links</h2>
        <p>
          Project pages link to third-party sites such as project websites, social networks,
          explorers and data sources. We do not control them, and their privacy practices are their
          own.
        </p>

        <h2>Contact</h2>
        <p>
          Questions about this policy: see the <Link href="/contact">contact page</Link>.
        </p>

        <p className="legal-updated">Last updated: {SITE.updated}</p>
      </article>
    </main>
  );
}
'@
WriteNew 'app\privacy\page.tsx' $privacy

# ---------- patch app\layout.tsx ----------
$layoutPath = (Resolve-Path -LiteralPath '.\app\layout.tsx').Path
$layout = [System.IO.File]::ReadAllText($layoutPath, [System.Text.Encoding]::UTF8)
if ($layout.Contains('Footer')) {
  Write-Host 'layout.tsx already has Footer, skipped.' -ForegroundColor Yellow
} else {
  $l = Patch $layout 'import AuroraBackground from "@/components/AuroraBackground";' ('import AuroraBackground from "@/components/AuroraBackground";' + "`r`n" + 'import Footer from "@/components/Footer";') 'layout import'
  if ($null -eq $l) { exit 1 }
  $l = Patch $l '{children}</body>' '{children}<Footer/></body>' 'layout footer'
  if ($null -eq $l) { exit 1 }
  Copy-Item -LiteralPath $layoutPath "${layoutPath}.bak-redesign10"
  [System.IO.File]::WriteAllText($layoutPath, $l, $utf8)
  Write-Host 'layout.tsx patched.' -ForegroundColor Green
}

# ---------- patch app\sitemap.ts ----------
if (Test-Path -LiteralPath '.\app\sitemap.ts') {
  $smPath = (Resolve-Path -LiteralPath '.\app\sitemap.ts').Path
  $sm = [System.IO.File]::ReadAllText($smPath, [System.Text.Encoding]::UTF8)
  if ($sm.Contains('/disclaimer')) {
    Write-Host 'sitemap.ts already lists the trust pages, skipped.' -ForegroundColor Yellow
  } else {
    $legal = @'
const legalRoutes: MetadataRoute.Sitemap = ["/about", "/contact", "/disclaimer", "/privacy"].map((route) => ({
    url: `${BASE}${route}`,
    lastModified: new Date("__LEGALDATE__"),
  }));

  return [...staticRoutes, ...legalRoutes, ...projectRoutes];
'@
    $legal = $legal.Replace('__LEGALDATE__', (Get-Date).ToString('yyyy-MM-dd'))
    $s = Patch $sm 'return [...staticRoutes, ...projectRoutes];' $legal.TrimEnd() 'sitemap routes'
    if ($null -eq $s) {
      Write-Host 'sitemap.ts was not changed. Add /about /contact /disclaimer /privacy to it by hand.' -ForegroundColor Yellow
    } else {
      Copy-Item -LiteralPath $smPath "${smPath}.bak-redesign10"
      [System.IO.File]::WriteAllText($smPath, $s, $utf8)
      Write-Host 'sitemap.ts patched.' -ForegroundColor Green
    }
  }
}

# ---------- styles ----------
$cssPath = '.\app\globals.css'
if (Test-Path -LiteralPath $cssPath) {
  $cssFull = (Resolve-Path -LiteralPath $cssPath).Path
  $cssText = [System.IO.File]::ReadAllText($cssFull, [System.Text.Encoding]::UTF8)
  if (-not $cssText.Contains('.site-footer')) {
    Copy-Item -LiteralPath $cssFull "${cssFull}.bak-redesign10"
    $add = @'

/* redesign-10: trust pages + footer */
.legal-card {
  max-width: 780px;
  margin: 0 auto;
}
.legal-card h1 {
  font-size: 32px;
  margin: 0 0 16px;
}
.legal-card h2 {
  font-size: 20px;
  margin: 28px 0 8px;
}
.legal-card p,
.legal-card li {
  font-size: 15px;
  line-height: 1.7;
  opacity: 0.9;
}
.legal-card ul {
  padding-left: 20px;
  margin: 8px 0;
}
.legal-card a {
  text-decoration: underline;
}
.legal-updated {
  margin-top: 24px;
  font-size: 12px !important;
  opacity: 0.6 !important;
}
.site-footer {
  position: relative;
  z-index: 1;
  margin-top: 64px;
  padding: 32px 24px 24px;
  border-top: 1px solid rgba(255, 255, 255, 0.08);
}
.site-footer__inner {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  gap: 32px;
  flex-wrap: wrap;
}
.site-footer__brand {
  max-width: 460px;
  font-size: 13px;
  line-height: 1.6;
  opacity: 0.75;
}
.site-footer__brand p {
  margin: 8px 0 0;
}
.site-footer__nav {
  display: flex;
  flex-wrap: wrap;
  gap: 20px;
  font-size: 14px;
}
.site-footer__nav a {
  opacity: 0.85;
}
.site-footer__nav a:hover {
  opacity: 1;
}
.site-footer__bottom {
  max-width: 1200px;
  margin: 24px auto 0;
  font-size: 12px;
  opacity: 0.55;
}
'@
    [System.IO.File]::WriteAllText($cssFull, $cssText + $add, $utf8)
    Write-Host 'globals.css: styles added.' -ForegroundColor Green
  }
} else {
  Write-Host 'app\globals.css not found: styles were NOT added.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Done. Restart the dev server and open /about, /contact, /disclaimer, /privacy. The footer shows on every page.' -ForegroundColor Green
