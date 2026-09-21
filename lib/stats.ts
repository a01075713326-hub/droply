import { Project } from "@/data/projects";

export type ChainStat = { chain: string; count: number };
export type StatusStat = { status: string; count: number };

export type DropStats = {
  total: number;
  newToday: number;
  newThisWeek: number;
  byChain: ChainStat[];
  byStatus: StatusStat[];
};

function daysAgo(iso?: string): number {
  if (!iso) return Infinity;
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return Infinity;
  return (Date.now() - then) / (1000 * 60 * 60 * 24);
}

function splitChains(value: string): string[] {
  return value
    .split(",")
    .map((c) => c.trim())
    .filter(Boolean);
}

export function computeStats(projects: Project[]): DropStats {
  const chainCounts = new Map<string, number>();
  const statusCounts = new Map<string, number>();
  let newToday = 0;
  let newThisWeek = 0;

  for (const p of projects) {
    for (const chain of splitChains(p.chain || "Other")) {
      chainCounts.set(chain, (chainCounts.get(chain) || 0) + 1);
    }

    statusCounts.set(p.status, (statusCounts.get(p.status) || 0) + 1);

    const age = daysAgo(p.firstSeenAt);
    if (age <= 1) newToday += 1;
    if (age <= 7) newThisWeek += 1;
  }

  const byChain = Array.from(chainCounts, ([chain, count]) => ({ chain, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 10);

  const byStatus = Array.from(statusCounts, ([status, count]) => ({ status, count })).sort(
    (a, b) => b.count - a.count
  );

  return { total: projects.length, newToday, newThisWeek, byChain, byStatus };
}
