export function parseProjectDate(raw?: string): Date | null {
  if (!raw) return null;
  const trimmed = raw.trim();
  if (!trimmed || /^(tba|tbd|n\/?a|unknown)$/i.test(trimmed)) return null;

  if (/^\d{4}-\d{2}-\d{2}/.test(trimmed)) {
    const d = new Date(trimmed);
    return isNaN(d.getTime()) ? null : d;
  }

  const d = new Date(trimmed);
  return isNaN(d.getTime()) ? null : d;
}

export function formatDate(raw?: string): string {
  const d = parseProjectDate(raw);
  if (!d) return "TBA";
  return d.toLocaleDateString("en-US", { month: "short", day: "numeric", year: "numeric" });
}

export type DeadlineStatus = "ending-soon" | "ended" | null;

export function getDeadlineStatus(deadline?: string, fallbackDate?: string): DeadlineStatus {
  const d = parseProjectDate(deadline) ?? parseProjectDate(fallbackDate);
  if (!d) return null;

  const now = new Date();
  const daysLeft = (d.getTime() - now.getTime()) / (1000 * 60 * 60 * 24);

  if (daysLeft < 0) return "ended";
  if (daysLeft <= 3) return "ending-soon";
  return null;
}