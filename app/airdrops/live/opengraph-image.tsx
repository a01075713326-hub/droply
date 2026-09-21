import { getProjects } from "@/lib/projects";
import { getLiveProjects } from "@/lib/hubs";
import { listImage } from "@/lib/og";
import type { Project } from "@/data/projects";

export const alt = "Droply - Live Crypto Airdrops";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image() {
  const all = (await Promise.resolve(getProjects())) as unknown as Project[];
  const n = getLiveProjects(all).length;
  return listImage(
    "AIRDROP TRACKER",
    "Live Crypto Airdrops",
    n + " projects tracked. Snapshots, TGE dates and claims, updated automatically."
  );
}