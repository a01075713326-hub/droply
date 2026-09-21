import { getProjects } from "@/lib/projects";
import { getCategoryHubs } from "@/lib/hubs";
import { listImage } from "@/lib/og";
import type { Project } from "@/data/projects";

export const alt = "Droply - CATEGORY airdrops";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image({ params }: { params: Promise<{ category: string }> }) {
  const { category } = await params;
  const all = (await Promise.resolve(getProjects())) as unknown as Project[];
  const hub = getCategoryHubs(all).find((h) => h.slug === category);
  const name = hub ? hub.name : category;
  const n = hub ? hub.items.length : 0;
  return listImage(
    "CATEGORY",
    name + " Airdrops",
    n + " tracked airdrops. Snapshots, TGE dates and claims, updated automatically."
  );
}