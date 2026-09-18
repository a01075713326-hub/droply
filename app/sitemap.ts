import { MetadataRoute } from "next";
import { getProjects } from "@/lib/projects";

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const base = "https://droply.digital";
  const projects = await getProjects();

  const staticRoutes: MetadataRoute.Sitemap = ["", "/airdrops", "/calendar"].map((route) => ({
    url: `${base}${route}`,
    lastModified: new Date(),
    changeFrequency: "daily",
  }));

  const projectRoutes: MetadataRoute.Sitemap = projects.map((p) => ({
    url: `${base}/project/${p.slug}`,
    lastModified: p.date ? new Date(`${p.date}T12:00:00`) : new Date(),
    changeFrequency: "daily",
    priority: 0.8,
  }));

  return [...staticRoutes, ...projectRoutes];
}