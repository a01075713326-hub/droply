/* Pure, client-safe helpers with no server-only imports (no "node:fs",
   "node:path", or @/lib/overrides). Anything imported here is safe to use
   from "use client" components like ProjectCards.tsx.
   lib/projects.ts re-exports these for server-side callers, so this file
   is the only one that should ever be imported from client components. */

export function initials(name: string) {
  return name.slice(0, 2).toUpperCase();
}

export function formatDate(date?: string) {
  if (!date) return "TBA";
  const parsed = new Date(`${date}T12:00:00`);
  if (Number.isNaN(parsed.getTime())) return "TBA";
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(parsed);
}

export function truncate(text: string, max: number) {
  if (!text || text.length <= max) return text;
  const cut = text.slice(0, max);
  const lastSpace = cut.lastIndexOf(' ');
  return (lastSpace > 0 ? cut.slice(0, lastSpace) : cut).trim() + '...';
}

export function shortAction(text: string) {
  const parts = text.split(":");
  if (parts.length >= 2) return parts[1].trim();
  return text.length > 30 ? text.slice(0, 30).trim() + "..." : text;
}

export function cardActions(actions?: string[]) {
  if (!actions || !actions.length) return "";
  return actions.slice(0, 3).map(shortAction).join(", ");
}
