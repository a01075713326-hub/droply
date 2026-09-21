import { getProjects } from "@/lib/projects";
import { getChainHubs } from "@/lib/hubs";
import { listImage } from "@/lib/og";
import type { Project } from "@/data/projects";

export const alt = "Droply - CHAIN airdrops";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image({ params }: { params: Promise<{ chain: string }> }) {
  const { chain } = await params;
  const all = (await Promise.resolve(getProjects())) as unknown as Project[];
  const hub = getChainHubs(all).find((h) => h.slug === chain);
  const name = hub ? hub.name : chain;
  const n = hub ? hub.items.length : 0;
  return listImage(
    "CHAIN",
    name + " Airdrops",
    n + " tracked airdrops. Snapshots, TGE dates and claims, updated automatically."
  );
}