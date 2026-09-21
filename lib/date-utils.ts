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
  const real = parseProjectDate(deadline);
  const d = real ?? parseProjectDate(fallbackDate);
  const isRealDeadline = real !== null;
  if (!d) return null;

  const now = new Date();
  // A date-only deadline (YYYY-MM-DD) is valid until the end of that day.
  const endOfDay = typeof deadline === "string" && /^\d{4}-\d{2}-\d{2}$/.test(deadline.trim()) ? 24 * 60 * 60 * 1000 : 0;
  const daysLeft = (d.getTime() + (isRealDeadline ? endOfDay : 0) - now.getTime()) / (1000 * 60 * 60 * 24);

  // "Ended" only for a real deadline. A fallback date in the past (for example the sync day) does not mean the campaign is over.
  if (daysLeft < 0) return isRealDeadline ? "ended" : null;
  if (daysLeft <= 3) return "ending-soon";
  return null;
}