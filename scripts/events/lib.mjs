// scripts/events/lib.mjs
// Shared helpers for the Droply events feed. Every collector produces events
// in the same shape and merges them into data/events.json.
//
// Event shape:
// {
//   id, type,            // type: "funding" | "listing" | "staking" | "tge"
//   project, slug,
//   date,                // ISO string, when the event happened / was announced
//   title, url, source,  // source: collector name, e.g. "defillama-raises"
//   data: {},            // type-specific details
//   firstSeenAt          // when Droply first saw it
// }

import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));

export const ROOT = path.resolve(here, "..", "..");
export const EVENTS_FILE = path.join(ROOT, "data", "events.json");

export function slugify(value) {
  return String(value || "")
    .toLowerCase()
    .trim()
    .replace(/['\u2019]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

export function makeId(parts) {
  return crypto
    .createHash("sha1")
    .update(parts.map((p) => String(p ?? "")).join("|"))
    .digest("hex")
    .slice(0, 16);
}

export async function loadEvents() {
  try {
    const text = (await fs.readFile(EVENTS_FILE, "utf8")).replace(/^\uFEFF/, "");
    const items = JSON.parse(text);
    return Array.isArray(items) ? items : [];
  } catch {
    return [];
  }
}

export async function saveEvents(events) {
  await fs.mkdir(path.dirname(EVENTS_FILE), { recursive: true });
  const tmp = EVENTS_FILE + ".tmp";
  await fs.writeFile(tmp, JSON.stringify(events, null, 2), "utf8");
  await fs.rename(tmp, EVENTS_FILE);
}

/**
 * Merge incoming events into the existing list by id.
 * Existing events keep their firstSeenAt; fields are refreshed from incoming.
 * Returns { events (newest first), added (count of new ids) }.
 */
export function mergeEvents(existing, incoming) {
  const byId = new Map(existing.map((e) => [e.id, e]));
  let added = 0;
  const now = new Date().toISOString();

  for (const ev of incoming) {
    if (!ev?.id) continue;
    const prev = byId.get(ev.id);
    if (prev) {
      byId.set(ev.id, { ...prev, ...ev, firstSeenAt: prev.firstSeenAt || now });
    } else {
      byId.set(ev.id, { ...ev, firstSeenAt: now });
      added++;
    }
  }

  const events = [...byId.values()].sort(
    (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime()
  );
  return { events, added };
}
