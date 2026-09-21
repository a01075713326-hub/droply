import { projects as allProjects, type Project } from "@/data/projects";
import { getBadges } from "@/lib/verification";
import type { VerificationBadge } from "@/data/verification";

/* ---- Source cleanup ----
   Guide text scraped from Airdrops.io contains links that do not work on our
   domain (/visit/..., /goto/...) or that send visitors to the source's own
   affiliate and guide pages. They are turned into plain text here, once, so
   every page (lists, project page, sitemap) sees the same clean data. */

const MD_LINK = /\[([^\]]+)\]\(([^)\s]+)\)/g;
const SOURCE_HOST = /^https?:\/\/(?:www\.)?(?:airdrops\.io|airdropalert\.com)(?:[/:?#]|$)/i;
const REFERRAL_SENTENCE = /\s*Using (?:this|our) link[^.]*\./gi;
const BAD_SOCIAL = /(?:t\.me\/airdrops_io|t\.me\/airdropalert\w*|airdrops\.io|airdropalert\.com)/i;

function isSourceLink(url: string): boolean {
  return url.startsWith("/") || SOURCE_HOST.test(url);
}

/* ---- Referral cleanup ----
   Source guides link to their own referral or partner URLs (the source earns the
   commission). Such links are reduced to the plain site address so the site does
   not carry someone else's referral. */

const REF_KEY = /^(?:r|code|via|aff|affiliate|invite\w*|ref\w*|utm_\w+)$/i;
const REF_PATH = /\/(?:ref|refer|referral|referrals|r|invite|join|share|u|b)(?:\/|$)/i;
const REF_HINT = /airdrop-?alert|aalert|airdropaa/i;
const HOST_PREFIX = /^(?:partner|invite|link|go|refer|ref|track|click)\./i;
const SKIP_HOST = /(?:^|\.)(?:discord\.gg|discord\.com|t\.me|telegram\.me|x\.com|twitter\.com|youtube\.com|github\.com|medium\.com)$/i;

function stripReferral(url: string): string {
  let u: URL;
  try {
    u = new URL(url);
  } catch {
    return url;
  }
  if (SKIP_HOST.test(u.hostname)) return url;

  if (HOST_PREFIX.test(u.hostname) || REF_PATH.test(u.pathname) || REF_HINT.test(url)) {
    return u.protocol + "//" + u.hostname.replace(HOST_PREFIX, "") + "/";
  }

  const keys: string[] = [];
  u.searchParams.forEach((_v, k) => keys.push(k));
  let changed = false;
  for (const k of keys) {
    if (REF_KEY.test(k)) {
      u.searchParams.delete(k);
      changed = true;
    }
  }
  return changed ? u.toString() : url;
}

function cleanStepText(text: string): string {
  if (typeof text !== "string") return text;

  let removed = false;
  const out = text.replace(MD_LINK, (match: string, label: string, url: string) => {
    if (isSourceLink(url)) {
      removed = true;
      return label;
    }
    const cleaned = stripReferral(url);
    if (cleaned !== url) {
      removed = true;
      return "[" + label + "](" + cleaned + ")";
    }
    return match;
  });

  return removed ? out.replace(REFERRAL_SENTENCE, "") : out;
}

function sanitizeProject(p: Project): Project {
  const out: Project = { ...p };

  if (out.actions) out.actions = out.actions.map(cleanStepText);

  if (out.tasks) {
    out.tasks = out.tasks.map((t) =>
      t.instructions ? { ...t, instructions: t.instructions.map(cleanStepText) } : t
    );
  }

  if (out.telegram && BAD_SOCIAL.test(out.telegram)) delete out.telegram;
  if (out.discord && BAD_SOCIAL.test(out.discord)) delete out.discord;
  if (out.x && BAD_SOCIAL.test(out.x)) delete out.x;

  if (out.claimUrl && isSourceLink(out.claimUrl)) delete out.claimUrl;
  if (out.website && isSourceLink(out.website)) delete out.website;
  if (out.claimUrl) out.claimUrl = stripReferral(out.claimUrl);
  if (out.website) out.website = stripReferral(out.website);

  if (out.extraLinks) {
    out.extraLinks = out.extraLinks.filter((l) => l && l.url && !isSourceLink(l.url)).map((l) => ({ ...l, url: stripReferral(l.url) }));
  }

  return out;
}

let cleanCache: Project[] | null = null;

function getCleanProjects(): Project[] {
  if (!cleanCache) cleanCache = allProjects.map(sanitizeProject);
  return cleanCache;
}
export async function getProjects(): Promise<Project[]> {
  return getCleanProjects();
}

export async function getProject(slug: string) {
  const items = await getProjects();
  return items.find((project) => project.slug === slug);
}

/** Project list with its verification badge attached, for /airdrops.
 *  One merge pass instead of a lookup per card. */
export type ProjectWithBadge = Project & { verification?: VerificationBadge };

export async function getProjectsWithBadges(): Promise<ProjectWithBadge[]> {
  const badges = getBadges();
  const items = await getProjects();

  return items.map((project) => ({
    ...project,
    verification: badges[project.slug],
  }));
}

/** Used by the "verified only" filter. Verified means the official site
 *  check passed — not that the project is safe. */
export function isVerified(project: ProjectWithBadge) {
  return Boolean(project.verification?.linksVerified);
}

export function formatDate(date?: string) {
  if (!date) return "TBA";
  const parsed = new Date(`${date}T12:00:00`);
  if (Number.isNaN(parsed.getTime())) return "TBA";
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", year: "numeric" }).format(parsed);
}

export function initials(name: string) { return name.slice(0, 2).toUpperCase(); }
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
