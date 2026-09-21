# redesign-cryptorank-8.ps1  (run from the project root, after redesign-cryptorank-6.ps1)
# Rewrites lib\og.tsx:
#  - puts public\droplet-logo.png on the Droply brand card and in the footer of every card
#  - detects logo format by file signature (PNG/JPEG only), so mislabeled images
#    (e.g. WebP served as PNG) fall back to initials instead of a blank spot
#  - draws project logos on a dark round plate
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-redesign8"
  if ((Test-Path -LiteralPath $p) -and -not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$ogPath   = Join-Path $root "lib\og.tsx"
$logoPath = Join-Path $root "public\droplet-logo.png"

if (-not (Test-Path -LiteralPath $ogPath))   { throw "Не найден $ogPath. Сначала запустите redesign-cryptorank-6.ps1 из корня проекта." }
if (-not (Test-Path -LiteralPath $logoPath)) { Write-Host "Внимание: public\droplet-logo.png не найден, карточка будет без логотипа." }

$og = @'
/* eslint-disable @next/next/no-img-element */
import { ImageResponse } from "next/og";
import { promises as fs } from "fs";
import path from "path";
import type { ReactNode } from "react";

const SIZE = { width: 1200, height: 630 };
const BG = "linear-gradient(135deg, #0a0a14 0%, #1b1033 55%, #0d1a2e 100%)";
const ACCENT = "linear-gradient(90deg, #22d3ee, #8b5cf6)";
const BRAND_LOGO = "/droplet-logo.png";

// Real format from the file signature; only PNG and JPEG are drawn.
function sniff(buf: Buffer): "image/png" | "image/jpeg" | null {
  if (buf.length > 8 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) {
    return "image/png";
  }
  if (buf.length > 3 && buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) {
    return "image/jpeg";
  }
  return null;
}

function toDataUri(buf: Buffer): string | null {
  if (buf.length > 1500000) return null;
  const type = sniff(buf);
  return type ? "data:" + type + ";base64," + buf.toString("base64") : null;
}

// Logo -> data URI, or null (initials are drawn instead).
async function loadLogo(url?: string): Promise<string | null> {
  if (!url || url.includes("..")) return null;
  try {
    if (/^https?:\/\//i.test(url)) {
      const ctrl = new AbortController();
      const timer = setTimeout(() => ctrl.abort(), 4000);
      const res = await fetch(url, { signal: ctrl.signal });
      clearTimeout(timer);
      if (!res.ok) return null;
      return toDataUri(Buffer.from(await res.arrayBuffer()));
    }
    if (url.startsWith("/")) {
      const file = path.join(process.cwd(), "public", url.split("?")[0]);
      return toDataUri(await fs.readFile(file));
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

function Frame({ children, brand }: { children: ReactNode; brand?: string | null }) {
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
        <div style={{ display: "flex", alignItems: "center", gap: 14 }}>
          {brand ? (
            <img src={brand} width={44} height={44} alt="" style={{ objectFit: "contain" }} />
          ) : null}
          <div style={{ display: "flex", fontSize: 34, color: "#a5b4fc" }}>droply.digital</div>
        </div>
        <div style={{ display: "flex", height: 8, width: 220, borderRadius: 4, background: ACCENT }} />
      </div>
    </div>
  );
}

export async function brandImage() {
  const brand = await loadLogo(BRAND_LOGO);

  return new ImageResponse(
    (
      <Frame brand={brand}>
        <div style={{ display: "flex", flexDirection: "column", gap: 24 }}>
          <div style={{ display: "flex", fontSize: 30, letterSpacing: 6, color: "#a5b4fc" }}>
            CRYPTO AIRDROP TRACKER
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 32 }}>
            {brand ? (
              <img src={brand} width={150} height={150} alt="" style={{ objectFit: "contain" }} />
            ) : null}
            <div style={{ display: "flex", fontSize: 148, lineHeight: 1 }}>Droply</div>
          </div>
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

  const [logo, brand] = await Promise.all([loadLogo(p.logo), loadLogo(BRAND_LOGO)]);
  const name = p.name.length > 34 ? p.name.slice(0, 33) + "\u2026" : p.name;
  const nameSize = name.length > 22 ? 62 : 84;
  const chain = p.chain ? String(p.chain).split(",")[0].trim() : "";
  const event = p.event ? String(p.event).split(",")[0].trim() : "";
  const status = p.status ? String(p.status) : "";
  const statusTone: Tone = status === "Confirmed" || status === "Live" ? "purple" : "gold";

  return new ImageResponse(
    (
      <Frame brand={brand}>
        <div style={{ display: "flex", alignItems: "center", gap: 44 }}>
          {logo ? (
            <div
              style={{
                display: "flex",
                width: 190,
                height: 190,
                borderRadius: 95,
                overflow: "hidden",
                background: "#111827",
              }}
            >
              <img src={logo} width={190} height={190} alt="" style={{ objectFit: "cover" }} />
            </div>
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

Backup $ogPath
Write-Text $ogPath $og
Write-Host "lib\og.tsx: обновлён (логотип Droply, проверка формата логотипов проектов)"

Write-Host ""
Write-Host "Готово. Резервная копия: lib\og.tsx.bak-redesign8"
Write-Host "Проверка (npm run dev):"
Write-Host "  http://localhost:3000/opengraph-image"
Write-Host "  http://localhost:3000/project/ekiden/opengraph-image"
