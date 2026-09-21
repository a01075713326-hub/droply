import fs from "node:fs";
import path from "node:path";

const EXTS = ["svg", "png", "webp", "jpg"];

/**
 * Own logo file for a chain: public/chains/<slug>.svg | .png | .webp
 * Server-side only (uses fs).
 */
export function chainIconSrc(slug: string): string | null {
  for (const ext of EXTS) {
    const file = path.join(process.cwd(), "public", "chains", `${slug}.${ext}`);
    if (fs.existsSync(file)) return `/chains/${slug}.${ext}`;
  }
  return null;
}

// [background, text] of the letter badge that is shown while there is no logo file.
const BRAND: Record<string, [string, string]> = {
  solana: ["#9945FF", "#FFFFFF"],
  base: ["#0052FF", "#FFFFFF"],
  ethereum: ["#627EEA", "#FFFFFF"],
  "bnb-chain": ["#F3BA2F", "#1A1A1A"],
  arbitrum: ["#28A0F0", "#FFFFFF"],
  hyperliquid: ["#97FCE4", "#0B2B26"],
  polygon: ["#8247E5", "#FFFFFF"],
  robinhood: ["#00C805", "#04210A"],
};

export function chainColors(slug: string): [string, string] {
  const known = BRAND[slug];
  if (known) return known;
  let hue = 0;
  for (let i = 0; i < slug.length; i++) {
    hue = (hue * 31 + slug.charCodeAt(i)) % 360;
  }
  return [`hsl(${hue}, 55%, 42%)`, "#FFFFFF"];
}