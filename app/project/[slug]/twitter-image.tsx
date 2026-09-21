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