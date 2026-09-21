# redesign-cryptorank-6.ps1  (run from the project root)
# Adds generated social-share images (1200x630):
#  - app\opengraph-image.tsx + twitter-image.tsx      -> Droply brand card (fallback for all pages)
#  - app\project\[slug]\opengraph-image.tsx + twitter-image.tsx -> per-project card (logo, name, status, chain)
#  - lib\og.tsx                                         -> shared drawing code
# and removes the small-logo "images" from generateMetadata so the new cards are used.
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Read-Text($p)      { [System.IO.File]::ReadAllText($p, $enc) }
function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-redesign6"
  if ((Test-Path -LiteralPath $p) -and -not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$libDir     = Join-Path $root "lib"
$appDir     = Join-Path $root "app"
$projectDir = Join-Path $root "app\project\[slug]"
$pagePath   = Join-Path $projectDir "page.tsx"

if (-not (Test-Path -LiteralPath $libDir))     { throw "Не найдена папка lib. Запускайте скрипт из корня проекта." }
if (-not (Test-Path -LiteralPath $projectDir)) { throw "Не найдена папка app\project\[slug]. Запускайте скрипт из корня проекта." }

# ---------------------------------------------------------------
# 1. lib\og.tsx
# ---------------------------------------------------------------
$og = @'
/* eslint-disable @next/next/no-img-element */
import { ImageResponse } from "next/og";
import { promises as fs } from "fs";
import path from "path";
import type { ReactNode } from "react";

const SIZE = { width: 1200, height: 630 };
const BG = "linear-gradient(135deg, #0a0a14 0%, #1b1033 55%, #0d1a2e 100%)";
const ACCENT = "linear-gradient(90deg, #22d3ee, #8b5cf6)";

// Logo -> data URI. Only PNG/JPEG are used; anything else falls back to initials.
async function loadLogo(url?: string): Promise<string | null> {
  if (!url || url.includes("..")) return null;
  try {
    if (/^https?:\/\//i.test(url)) {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 4000);
      const res = await fetch(url, { signal: ctrl.signal });
      clearTimeout(timer);
      if (!res.ok) return null;
      const type = (res.headers.get("content-type") || "").split(";")[0].trim().toLowerCase();
      if (type !== "image/png" && type !== "image/jpeg") return null;
      const buf = Buffer.from(await res.arrayBuffer());
      if (buf.length > 1500000) return null;
      return "data:" + type + ";base64," + buf.toString("base64");
    }
    if (url.startsWith("/")) {
      const file = path.join(process.cwd(), "public", url.split("?")[0]);
      const ext = path.extname(file).toLowerCase();
      const type =
        ext === ".png" ? "image/png" : ext === ".jpg" || ext === ".jpeg" ? "image/jpeg" : "";
      if (!type) return null;
      const buf = await fs.readFile(file);
      return "data:" + type + ";base64," + buf.toString("base64");
    }
  } catch {
    // fall through: initials are drawn instead
  }
  return null;
}

function initialsOf(name: string): string {
  const words = name.replace(/[^\p{L}\p{N} ]/gu, " ").split(/\s+/).filter(Boolean);
  const letters = words.length > 1 ? words[0][0] + words[1][0] : (words[0] || "?").slice(0, 2);
  return letters.toUpperCase();
}

type Tone = "purple" | "gold" | "plain";

function Pill({ text, tone = "plain" }: { text: string; tone?: Tone }) {
  const styles =
    tone === "purple"
      ? { color: "#ffffff", background: "linear-gradient(90deg, #a855f7, #7c3aed)", border: "1px solid #a855f7" }
      : tone === "gold"
        ? { color: "#f5c542", background: "rgba(245, 197, 66, 0.12)", border: "1px solid rgba(245, 197, 66, 0.4)" }
        : { color: "#c4b5fd", background: "rgba(139, 92, 246, 0.16)", border: "1px solid rgba(139, 92, 246, 0.35)" };

  return (
    <div style={{ display: "flex", padding: "10px 24px", borderRadius: 999, fontSize: 28, ...styles }}>
      {text}
    </div>
  );
}

function Frame({ children }: { children: ReactNode }) {
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: 64,
        background: BG,
        color: "#ffffff",
      }}
    >
      {children}
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div style={{ display: "flex", fontSize: 34, color: "#a5b4fc" }}>droply.digital</div>
        <div style={{ display: "flex", height: 8, width: 220, borderRadius: 4, background: ACCENT }} />
      </div>
    </div>
  );
}

export function brandImage() {
  return new ImageResponse(
    (
      <Frame>
        <div style={{ display: "flex", flexDirection: "column", gap: 24 }}>
          <div style={{ display: "flex", fontSize: 30, letterSpacing: 6, color: "#a5b4fc" }}>
            CRYPTO AIRDROP TRACKER
          </div>
          <div style={{ display: "flex", fontSize: 148, lineHeight: 1 }}>Droply</div>
          <div style={{ display: "flex", fontSize: 52, color: "#c4b5fd" }}>
            {"Track what's dropping."}
          </div>
        </div>
        <div style={{ display: "flex", gap: 14 }}>
          <Pill text="Airdrops" />
          <Pill text="Snapshots" />
          <Pill text="TGE" />
          <Pill text="Claims" />
        </div>
      </Frame>
    ),
    { ...SIZE }
  );
}

type OgProject = {
  name: string;
  status?: string;
  chain?: string;
  event?: string;
  logo?: string;
  symbol?: string;
};

export async function projectImage(p: OgProject | null | undefined) {
  if (!p || !p.name) return brandImage();

  const logo = await loadLogo(p.logo);
  const name = p.name.length > 34 ? p.name.slice(0, 33) + "\u2026" : p.name;
  const nameSize = name.length > 22 ? 62 : 84;
  const chain = p.chain ? String(p.chain).split(",")[0].trim() : "";
  const event = p.event ? String(p.event).split(",")[0].trim() : "";
  const status = p.status ? String(p.status) : "";
  const statusTone: Tone = status === "Confirmed" || status === "Live" ? "purple" : "gold";

  return new ImageResponse(
    (
      <Frame>
        <div style={{ display: "flex", alignItems: "center", gap: 44 }}>
          {logo ? (
            <img src={logo} width={190} height={190} alt="" style={{ borderRadius: 95 }} />
          ) : (
            <div
              style={{
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                width: 190,
                height: 190,
                borderRadius: 95,
                fontSize: 84,
                background: ACCENT,
              }}
            >
              {initialsOf(p.name)}
            </div>
          )}
          <div style={{ display: "flex", flexDirection: "column", gap: 14, maxWidth: 800 }}>
            <div style={{ display: "flex", fontSize: 30, letterSpacing: 5, color: "#a5b4fc" }}>
              AIRDROP GUIDE
            </div>
            <div style={{ display: "flex", fontSize: nameSize, lineHeight: 1.05 }}>{name}</div>
            {p.symbol ? (
              <div style={{ display: "flex", fontSize: 40, color: "#c4b5fd" }}>{"$" + p.symbol}</div>
            ) : null}
          </div>
        </div>
        <div style={{ display: "flex", gap: 14 }}>
          {status ? <Pill text={status} tone={statusTone} /> : null}
          {chain ? <Pill text={chain} /> : null}
          {event ? <Pill text={event} /> : null}
        </div>
      </Frame>
    ),
    { ...SIZE }
  );
}
'@

$ogPath = Join-Path $libDir "og.tsx"
if (Test-Path -LiteralPath $ogPath) {
  Write-Host "lib\og.tsx: уже существует, пропускаю"
} else {
  Write-Text $ogPath $og
  Write-Host "lib\og.tsx: создан"
}

# ---------------------------------------------------------------
# 2. Root brand images (fallback for every page without its own)
# ---------------------------------------------------------------
$rootImage = @'
import { brandImage } from "@/lib/og";

export const alt = "Droply \u2014 Track what's dropping.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function Image() {
  return brandImage();
}
'@

foreach ($name in @("opengraph-image.tsx", "twitter-image.tsx")) {
  $target = Join-Path $appDir $name
  if (Test-Path -LiteralPath $target) {
    Write-Host "app\${name}: уже существует, пропускаю"
  } else {
    Write-Text $target $rootImage
    Write-Host "app\${name}: создан"
  }
}

# ---------------------------------------------------------------
# 3. Per-project images
# ---------------------------------------------------------------
$projectImageTsx = @'
import { getProject } from "@/lib/projects";
import { projectImage } from "@/lib/og";

export const alt = "Airdrop guide";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const p = await getProject(slug);
  return projectImage(p as any);
}
'@

foreach ($name in @("opengraph-image.tsx", "twitter-image.tsx")) {
  $target = Join-Path $projectDir $name
  if (Test-Path -LiteralPath $target) {
    Write-Host "app\project\[slug]\${name}: уже существует, пропускаю"
  } else {
    Write-Text $target $projectImageTsx
    Write-Host "app\project\[slug]\${name}: создан"
  }
}

# ---------------------------------------------------------------
# 4. page.tsx: drop the small-logo "images" so the new cards win
# ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $pagePath)) {
  Write-Host "page.tsx: не найден, пропускаю правку метаданных"
} else {
  $page = Read-Text $pagePath
  $imgOg  = 'images: p.logo ? [{ url: p.logo }] : undefined,'
  $imgTw  = 'images: p.logo ? [p.logo] : undefined,'

  if ($page.Contains($imgOg) -or $page.Contains($imgTw)) {
    Backup $pagePath
    $page = $page.Replace($imgOg, '').Replace($imgTw, '')
    Write-Text $pagePath $page
    Write-Host "page.tsx: убраны images с логотипом из generateMetadata"
  } else {
    Write-Host "page.tsx: images в generateMetadata уже нет, пропускаю"
  }
}

Write-Host ""
Write-Host "Готово. Резервные копии: *.bak-redesign6"
Write-Host "Проверка: npm run dev, затем откройте в браузере:"
Write-Host "  http://localhost:3000/opengraph-image"
Write-Host "  http://localhost:3000/project/<slug-любого-проекта>/opengraph-image"

