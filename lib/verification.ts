import {
  mergeVerification,
  toBadge,
  type ProjectVerification,
  type VerificationBadge,
  type VerificationMap,
} from "@/data/verification";
import { generatedVerification } from "@/data/verification.generated";
import { manualVerification } from "@/data/verification.manual";

// Merged once per process. Both inputs are static files committed to
// the repo, so there's nothing to invalidate at runtime.
let cache: VerificationMap | null = null;

function all(): VerificationMap {
  if (!cache) {
    cache = mergeVerification(generatedVerification, manualVerification);
  }

  return cache;
}

export function getVerification(slug: string): ProjectVerification | undefined {
  return all()[slug];
}

export function getBadge(slug: string): VerificationBadge | undefined {
  return toBadge(all()[slug]);
}

/** For the /airdrops list: one pass, no per-card lookups. */
export function getBadges(): Record<string, VerificationBadge> {
  const out: Record<string, VerificationBadge> = {};

  for (const [slug, entry] of Object.entries(all())) {
    const badge = toBadge(entry);

    if (badge) out[slug] = badge;
  }

  return out;
}

export function isVerified(slug: string): boolean {
  return Boolean(getBadge(slug)?.linksVerified);
}
