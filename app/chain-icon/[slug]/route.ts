import fs from "node:fs";
import path from "node:path";
import { chainIconSrc, chainColors } from "@/lib/chain-icons";

export const dynamic = "force-dynamic";

const TYPES: Record<string, string> = {
  svg: "image/svg+xml",
  png: "image/png",
  jpg: "image/jpeg",
  webp: "image/webp",
};

export async function GET(
  _req: Request,
  { params }: { params: Promise<{ slug: string }> }
) {
  const { slug } = await params;
  if (!/^[a-z0-9-]{1,40}$/.test(slug)) {
    return new Response("Not found", { status: 404 });
  }

  // 1) logo file from public/chains
  const src = chainIconSrc(slug);
  if (src) {
    const ext = src.split(".").pop() || "png";
    try {
      const data = fs.readFileSync(path.join(process.cwd(), "public", src));
      return new Response(new Uint8Array(data), {
        headers: {
          "Content-Type": TYPES[ext] || "application/octet-stream",
          "Cache-Control": "public, max-age=3600",
        },
      });
    } catch {
      // fall through to the letter badge
    }
  }

  // 2) letter badge
  const [bg, fg] = chainColors(slug);
  const letter = slug.charAt(0).toUpperCase();
  const svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">' +
    `<circle cx="16" cy="16" r="16" fill="${bg}"/>` +
    `<text x="16" y="16" text-anchor="middle" dominant-baseline="central" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="${fg}">${letter}</text>` +
    "</svg>";
  return new Response(svg, {
    headers: {
      "Content-Type": "image/svg+xml",
      "Cache-Control": "public, max-age=3600",
    },
  });
}