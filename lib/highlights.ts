import fs from "node:fs";
import path from "node:path";
import type { Project } from "@/data/projects";

type HighlightsConfig = {
  nearestReward?: string;
  hotActivities?: string[];
};

function readConfig(): HighlightsConfig {
  try {
    const file = path.join(process.cwd(), "data", "highlights.json");
    const raw = fs.readFileSync(file, "utf8").replace(/^\uFEFF/, "");
    return JSON.parse(raw) as HighlightsConfig;
  } catch {
    return {};
  }
}

export function getNearestReward(projects: Project[]): Project | undefined {
  const cfg = readConfig();
  if (!cfg.nearestReward) return undefined;
  return projects.find((p) => p.slug === cfg.nearestReward);
}

export function getHotActivities(projects: Project[]): Project[] {
  const cfg = readConfig();
  if (!cfg.hotActivities?.length) return [];
  const bySlug = new Map(projects.map((p) => [p.slug, p]));
  return cfg.hotActivities
    .map((slug) => bySlug.get(slug))
    .filter((p): p is Project => Boolean(p));
}
