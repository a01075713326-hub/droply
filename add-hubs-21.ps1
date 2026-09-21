# add-hubs-21.ps1
# Creates hub pages: /chain/[chain], /category/[category], /airdrops/live
# Only NEW files are created. Existing files are not modified.
# Run from the project root:  powershell -ExecutionPolicy Bypass -File .\add-hubs-21.ps1

$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$utf8 = New-Object System.Text.UTF8Encoding($false)

# ---- 1. Check that we are in the right place -------------------------------
$need = @(
  "package.json",
  "app\airdrops\page.tsx",
  "components\ProjectCards.tsx",
  "lib\projects.ts",
  "data\projects.ts"
)
foreach ($n in $need) {
  $p = [System.IO.Path]::Combine($root, $n)
  if (-not (Test-Path -LiteralPath $p)) {
    Write-Host "NOT FOUND $n"
    Write-Host "Run this script from the project root."
    exit 1
  }
}

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$bk = [System.IO.Path]::Combine($root, "_backups")
[System.IO.Directory]::CreateDirectory($bk) | Out-Null

function Write-Ts($rel, $content) {
  $full = [System.IO.Path]::Combine($root, $rel)
  $dir = [System.IO.Path]::GetDirectoryName($full)
  [System.IO.Directory]::CreateDirectory($dir) | Out-Null
  if (Test-Path -LiteralPath $full) {
    $name = ($rel -replace '[\\/\[\]]', '_')
    Copy-Item -LiteralPath $full -Destination ([System.IO.Path]::Combine($bk, ($name + "." + $stamp + ".bak")))
    Write-Host "BACKUP of existing $rel"
  }
  [System.IO.File]::WriteAllText($full, $content, $utf8)
  Write-Host "WROTE $rel"
}

# ---- 2. lib\hubs.ts ---------------------------------------------------------
$hubsLib = @'
import type { Project } from "@/data/projects";

/** A hub page is created only when a chain/category has at least this many projects. */
export const HUB_MIN = 3;
export const SITE_URL = "https://droply.digital";

export type Hub = { slug: string; name: string; items: Project[] };

export function slugify(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function groupBy(
  projects: Project[],
  pick: (p: Project) => string | undefined
): Hub[] {
  const map = new Map<string, Hub>();
  for (const p of projects) {
    const raw = (pick(p) || "").trim();
    const slug = slugify(raw);
    if (!slug) continue;
    let hub = map.get(slug);
    if (!hub) {
      hub = { slug, name: raw, items: [] };
      map.set(slug, hub);
    }
    hub.items.push(p);
  }
  return Array.from(map.values())
    .filter((h) => h.items.length >= HUB_MIN)
    .sort(
      (a, b) => b.items.length - a.items.length || a.name.localeCompare(b.name)
    );
}

export function getChainHubs(projects: Project[]): Hub[] {
  return groupBy(projects, (p) => p.chain);
}

export function getCategoryHubs(projects: Project[]): Hub[] {
  return groupBy(projects, (p) => p.category);
}

export function getLiveProjects(projects: Project[]): Project[] {
  return projects.filter((p) => p.status === "Live");
}

const STATUS_ORDER = ["Live", "Upcoming", "Potential", "Confirmed"];

function statusPart(items: Project[]): string {
  const parts: string[] = [];
  for (const s of STATUS_ORDER) {
    const n = items.filter((p) => p.status === s).length;
    if (n > 0) parts.push(`${n} ${s.toLowerCase()}`);
  }
  return parts.join(", ");
}

function difficultySentence(items: Project[]): string {
  const counts = new Map<string, number>();
  let total = 0;
  for (const p of items) {
    const d = (p.difficulty || "").trim();
    if (!d) continue;
    total += 1;
    counts.set(d, (counts.get(d) || 0) + 1);
  }
  if (total < HUB_MIN) return "";
  let bestName = "";
  let bestCount = 0;
  for (const [d, n] of Array.from(counts.entries())) {
    if (n > bestCount) {
      bestName = d;
      bestCount = n;
    }
  }
  if (!bestName) return "";
  return `Of ${total} projects with a difficulty rating, ${bestCount} are rated ${bestName.toLowerCase()}.`;
}

function namesSentence(items: Project[]): string {
  const rank = (s: string) => {
    const i = STATUS_ORDER.indexOf(s);
    return i === -1 ? STATUS_ORDER.length : i;
  };
  const sorted = [...items].sort((a, b) => rank(a.status) - rank(b.status));
  const names = sorted.slice(0, 3).map((p) => p.name);
  if (names.length === 0) return "";
  if (names.length === 1) return `Includes ${names[0]}.`;
  const last = names[names.length - 1];
  return `Includes ${names.slice(0, -1).join(", ")} and ${last}.`;
}

/** Short intro built only from the data we actually have. */
export function describeHub(
  kind: "chain" | "category" | "live",
  name: string,
  items: Project[]
): string {
  const n = items.length;
  const noun = n === 1 ? "airdrop" : "airdrops";
  const sp = statusPart(items);
  const spText = sp ? ` (${sp})` : "";

  if (kind === "live" && n === 0) {
    return "No airdrops are marked live at the moment. Check the full list for upcoming and potential drops.";
  }

  let first: string;
  if (kind === "chain") {
    first = `Droply tracks ${n} ${name} ${noun}${spText}.`;
  } else if (kind === "category") {
    first = `Droply tracks ${n} ${noun} in the ${name} category${spText}.`;
  } else {
    first = `${n} ${noun} ${n === 1 ? "is" : "are"} marked live right now.`;
  }

  return [first, difficultySentence(items), namesSentence(items)]
    .filter(Boolean)
    .join(" ");
}

export function clip(text: string, max = 155): string {
  if (text.length <= max) return text;
  return text.slice(0, max - 3).trimEnd() + "...";
}

export function breadcrumbLd(trail: { name: string; path: string }[]) {
  return {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: trail.map((t, i) => ({
      "@type": "ListItem",
      position: i + 1,
      name: t.name,
      item: SITE_URL + t.path,
    })),
  };
}
'@

# ---- 3. app\chain\[chain]\page.tsx -----------------------------------------
$chainPage = @'
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import ProjectCards from "@/components/ProjectCards";
import { getProjects } from "@/lib/projects";
import {
  getChainHubs,
  describeHub,
  clip,
  breadcrumbLd,
  SITE_URL,
} from "@/lib/hubs";

export const dynamic = "force-dynamic";

type Props = { params: Promise<{ chain: string }> };

async function load(slug: string) {
  const projects = await getProjects();
  const hubs = getChainHubs(projects);
  const hub = hubs.find((h) => h.slug === slug);
  return { hub, hubs };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { chain } = await params;
  const { hub } = await load(chain);
  if (!hub) {
    return { title: "Not found", robots: { index: false, follow: false } };
  }
  const description = clip(describeHub("chain", hub.name, hub.items));
  const url = `${SITE_URL}/chain/${hub.slug}`;
  return {
    title: `${hub.name} Airdrops`,
    description,
    alternates: { canonical: url },
    openGraph: {
      title: `${hub.name} Airdrops - Droply`,
      description,
      url,
    },
  };
}

export default async function ChainHub({ params }: Props) {
  const { chain } = await params;
  const { hub, hubs } = await load(chain);
  if (!hub) notFound();

  const intro = describeHub("chain", hub.name, hub.items);
  const others = hubs.filter((h) => h.slug !== hub.slug).slice(0, 12);
  const ld = breadcrumbLd([
    { name: "Home", path: "/" },
    { name: "Airdrops", path: "/airdrops" },
    { name: `${hub.name} Airdrops`, path: `/chain/${hub.slug}` },
  ]);

  return (
    <main className="page container">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ld) }}
      />

      <div className="page-head">
        <div>
          <div className="section-kicker">CHAIN</div>
          <h1>{hub.name} Airdrops</h1>
          <p>{intro}</p>
        </div>
      </div>

      <ProjectCards items={hub.items} />

      <section style={{ marginTop: 40 }}>
        <h2>More airdrops</h2>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
          <Link className="type-pill" href="/airdrops">
            All airdrops
          </Link>
          <Link className="type-pill" href="/airdrops/live">
            Live airdrops
          </Link>
          {others.map((h) => (
            <Link className="type-pill" href={`/chain/${h.slug}`} key={h.slug}>
              {h.name} ({h.items.length})
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}
'@

# ---- 4. app\category\[category]\page.tsx -----------------------------------
$categoryPage = @'
import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import ProjectCards from "@/components/ProjectCards";
import { getProjects } from "@/lib/projects";
import {
  getCategoryHubs,
  describeHub,
  clip,
  breadcrumbLd,
  SITE_URL,
} from "@/lib/hubs";

export const dynamic = "force-dynamic";

type Props = { params: Promise<{ category: string }> };

async function load(slug: string) {
  const projects = await getProjects();
  const hubs = getCategoryHubs(projects);
  const hub = hubs.find((h) => h.slug === slug);
  return { hub, hubs };
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { category } = await params;
  const { hub } = await load(category);
  if (!hub) {
    return { title: "Not found", robots: { index: false, follow: false } };
  }
  const description = clip(describeHub("category", hub.name, hub.items));
  const url = `${SITE_URL}/category/${hub.slug}`;
  return {
    title: `${hub.name} Airdrops`,
    description,
    alternates: { canonical: url },
    openGraph: {
      title: `${hub.name} Airdrops - Droply`,
      description,
      url,
    },
  };
}

export default async function CategoryHub({ params }: Props) {
  const { category } = await params;
  const { hub, hubs } = await load(category);
  if (!hub) notFound();

  const intro = describeHub("category", hub.name, hub.items);
  const others = hubs.filter((h) => h.slug !== hub.slug).slice(0, 12);
  const ld = breadcrumbLd([
    { name: "Home", path: "/" },
    { name: "Airdrops", path: "/airdrops" },
    { name: `${hub.name} Airdrops`, path: `/category/${hub.slug}` },
  ]);

  return (
    <main className="page container">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ld) }}
      />

      <div className="page-head">
        <div>
          <div className="section-kicker">CATEGORY</div>
          <h1>{hub.name} Airdrops</h1>
          <p>{intro}</p>
        </div>
      </div>

      <ProjectCards items={hub.items} />

      <section style={{ marginTop: 40 }}>
        <h2>More airdrops</h2>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
          <Link className="type-pill" href="/airdrops">
            All airdrops
          </Link>
          <Link className="type-pill" href="/airdrops/live">
            Live airdrops
          </Link>
          {others.map((h) => (
            <Link
              className="type-pill"
              href={`/category/${h.slug}`}
              key={h.slug}
            >
              {h.name} ({h.items.length})
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}
'@

# ---- 5. app\airdrops\live\page.tsx -----------------------------------------
$livePage = @'
import type { Metadata } from "next";
import Link from "next/link";
import ProjectCards from "@/components/ProjectCards";
import { getProjects } from "@/lib/projects";
import {
  getChainHubs,
  getLiveProjects,
  describeHub,
  clip,
  breadcrumbLd,
  HUB_MIN,
  SITE_URL,
} from "@/lib/hubs";

export const dynamic = "force-dynamic";

export async function generateMetadata(): Promise<Metadata> {
  const projects = await getProjects();
  const live = getLiveProjects(projects);
  const description = clip(describeHub("live", "Live", live));
  const url = `${SITE_URL}/airdrops/live`;
  return {
    title: "Live Airdrops",
    description,
    alternates: { canonical: url },
    // A thin page (fewer than HUB_MIN projects) stays out of the index.
    robots: { index: live.length >= HUB_MIN, follow: true },
    openGraph: {
      title: "Live Airdrops - Droply",
      description,
      url,
    },
  };
}

export default async function LiveAirdrops() {
  const projects = await getProjects();
  const live = getLiveProjects(projects);
  const chains = getChainHubs(projects).slice(0, 12);
  const intro = describeHub("live", "Live", live);
  const ld = breadcrumbLd([
    { name: "Home", path: "/" },
    { name: "Airdrops", path: "/airdrops" },
    { name: "Live Airdrops", path: "/airdrops/live" },
  ]);

  return (
    <main className="page container">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ld) }}
      />

      <div className="page-head">
        <div>
          <div className="section-kicker">LIVE NOW</div>
          <h1>Live Airdrops</h1>
          <p>{intro}</p>
        </div>
      </div>

      {live.length > 0 ? (
        <ProjectCards items={live} />
      ) : (
        <p>
          <Link href="/airdrops">Browse all airdrops</Link>
        </p>
      )}

      <section style={{ marginTop: 40 }}>
        <h2>Browse by chain</h2>
        <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 12 }}>
          <Link className="type-pill" href="/airdrops">
            All airdrops
          </Link>
          {chains.map((h) => (
            <Link className="type-pill" href={`/chain/${h.slug}`} key={h.slug}>
              {h.name} ({h.items.length})
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}
'@

# ---- 6. Write everything ---------------------------------------------------
Write-Ts "lib\hubs.ts" $hubsLib
Write-Ts "app\chain\[chain]\page.tsx" $chainPage
Write-Ts "app\category\[category]\page.tsx" $categoryPage
Write-Ts "app\airdrops\live\page.tsx" $livePage

Write-Host ""
Write-Host "DONE. Restart 'npm run dev' and open /airdrops/live"
