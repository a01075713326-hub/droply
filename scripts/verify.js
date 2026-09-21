import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
import fs from "node:fs/promises";

/* =========================
   Config
========================= */

const DATA_DIR = path.join(__dirname, "..", "data");
const GENERATED = path.join(DATA_DIR, "projects.generated.ts");
const OUT = path.join(DATA_DIR, "verification.generated.ts");
const CACHE = path.join(DATA_DIR, ".verify-cache.json");

// Re-checking every project every day is wasteful and rude to the
// sites we fetch. A project is re-checked only if its cache entry is
// older than this, or if its website/x/discord changed in sync.
const RECHECK_AFTER_DAYS = Number(process.env.VERIFY_RECHECK_DAYS || 7);

// Hard cap per run so a growing project list can't turn into a
// multi-hour job. Oldest cache entries go first.
const MAX_PER_RUN = Number(process.env.VERIFY_MAX_PER_RUN || 120);

const CONCURRENCY = 4;
const FETCH_TIMEOUT_MS = 12_000;

const DEFILLAMA_PROTOCOLS = "https://api.llama.fi/protocols";
const RDAP = (domain) => `https://rdap.org/domain/${domain}`;
const SAFE_BROWSING =
  "https://safebrowsing.googleapis.com/v4/threatMatches:find";

const UA = "Mozilla/5.0 (compatible; Droply.digital verifier/1.0)";

const today = () => new Date().toISOString().slice(0, 10);

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const daysSince = (iso) => {
  if (!iso) return Infinity;

  const then = new Date(iso).getTime();

  if (Number.isNaN(then)) return Infinity;

  return (Date.now() - then) / 86_400_000;
};

/* =========================
   Fetch helpers
========================= */

// Never let one hanging site stall the whole run, and never throw:
// a failed check is "unverified", not a crashed workflow.
async function get(url, { headers = {}, json = false } = {}) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const r = await fetch(url, {
      headers: { "User-Agent": UA, Accept: json ? "application/json" : "text/html,*/*", ...headers },
      redirect: "follow",
      signal: controller.signal,
    });

    if (!r.ok) return { ok: false, status: r.status, url: r.url };

    const body = json ? await r.json() : await r.text();

    return { ok: true, status: r.status, url: r.url, body };
  } catch (error) {
    return { ok: false, status: 0, error: error?.message || "request failed" };
  } finally {
    clearTimeout(timer);
  }
}

async function post(url, payload) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);

  try {
    const r = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });

    if (!r.ok) return { ok: false, status: r.status };

    return { ok: true, body: await r.json() };
  } catch (error) {
    return { ok: false, status: 0, error: error?.message || "request failed" };
  } finally {
    clearTimeout(timer);
  }
}

/* =========================
   URL / domain helpers
========================= */

const hostOf = (url) => {
  try {
    return new URL(url).hostname.replace(/^www\./i, "").toLowerCase();
  } catch {
    return "";
  }
};

// example.co.uk -> example.co.uk, app.example.xyz -> example.xyz.
// Deliberately naive; RDAP tolerates a subdomain miss by 404ing, and
// we fall back to the full host in that case.
const registrableOf = (host) => {
  const parts = host.split(".");

  if (parts.length <= 2) return host;

  const twoLevelTlds = /^(co|com|org|net|gov|ac)\.[a-z]{2}$/i;
  const tail = parts.slice(-2).join(".");

  return twoLevelTlds.test(tail) ? parts.slice(-3).join(".") : tail;
};

const handleOf = (url) => {
  const match = String(url || "").match(
    /^https?:\/\/(?:www\.)?(?:x|twitter)\.com\/([A-Za-z0-9_]{1,15})/i
  );

  return match ? match[1].toLowerCase() : "";
};

/* =========================
   Site parsing
========================= */

const X_RE = /https?:\/\/(?:www\.)?(?:x|twitter)\.com\/([A-Za-z0-9_]{1,15})(?![A-Za-z0-9_])/gi;
const DISCORD_RE = /https?:\/\/(?:www\.)?discord(?:\.gg|\.com\/invite)\/[A-Za-z0-9-]+/gi;
const TELEGRAM_RE = /https?:\/\/(?:www\.)?t\.me\/[A-Za-z0-9_+]+/gi;
const DOCS_RE = /https?:\/\/[^"'\s<>]*(?:docs?|gitbook|whitepaper)[^"'\s<>]*/gi;

// Handles that appear on half the web and say nothing about the project.
const IGNORED_HANDLES = new Set([
  "intent", "share", "home", "i", "search", "hashtag",
  "elonmusk", "x", "twitter", "vercel", "nextjs", "github",
]);

function extractSiteLinks(html) {
  const uniq = (matches) => [...new Set(matches.map((m) => m[0]))];

  const xHandles = [
    ...new Set(
      [...html.matchAll(X_RE)]
        .map((m) => m[1].toLowerCase())
        .filter((h) => !IGNORED_HANDLES.has(h))
    ),
  ];

  return {
    x: xHandles,
    discord: uniq([...html.matchAll(DISCORD_RE)]),
    telegram: uniq([...html.matchAll(TELEGRAM_RE)]),
    docs: uniq([...html.matchAll(DOCS_RE)]).slice(0, 3),
  };
}

/* =========================
   Checks
========================= */

// The strongest free signal: the site points at a social profile and
// that profile points back at the same domain. A phishing clone copies
// the site but can't make the real X account link to its domain.
//
// x.com blocks unauthenticated page fetches, so this returns
// "unverified" far more often than it returns "confirmed". That's the
// honest outcome — never downgrade a failed fetch into a mismatch.
async function backlinkCheck(profileUrl, domain) {
  const r = await get(profileUrl);

  if (!r.ok) {
    return { status: "unverified", note: "Profile could not be read automatically" };
  }

  const body = String(r.body).toLowerCase();

  if (body.includes(domain)) {
    return { status: "confirmed", note: "Profile links back to the official domain" };
  }

  return { status: "unverified", note: "No link back to the domain found on the profile" };
}

// Registration age via RDAP. Free, no key, works for most gTLDs.
// Some ccTLDs have no RDAP server — that's "unknown", not "new".
async function domainAge(domain) {
  const r = await get(RDAP(domain), { json: true });

  if (!r.ok) return { ageDays: undefined, source: RDAP(domain) };

  const events = r.body?.events || [];
  const registered = events.find(
    (e) => String(e.eventAction).toLowerCase() === "registration"
  )?.eventDate;

  if (!registered) return { ageDays: undefined, source: RDAP(domain) };

  return { ageDays: Math.floor(daysSince(registered)), registered, source: RDAP(domain) };
}

async function safeBrowsing(urls) {
  const key = process.env.GOOGLE_SAFE_BROWSING_KEY;

  if (!key || !urls.length) return { checked: false, hits: [] };

  const r = await post(`${SAFE_BROWSING}?key=${key}`, {
    client: { clientId: "droply-digital", clientVersion: "1.0" },
    threatInfo: {
      threatTypes: ["MALWARE", "SOCIAL_ENGINEERING", "UNWANTED_SOFTWARE"],
      platformTypes: ["ANY_PLATFORM"],
      threatEntryTypes: ["URL"],
      threatEntries: urls.map((url) => ({ url })),
    },
  });

  if (!r.ok) return { checked: false, hits: [] };

  return { checked: true, hits: r.body?.matches || [] };
}

// DefiLlama is the only free public source with audit links attached
// to protocols. Coverage is mostly protocols with TVL, so most
// early-stage airdrop projects simply aren't there.
async function loadDefiLlama() {
  const r = await get(DEFILLAMA_PROTOCOLS, { json: true });

  if (!r.ok) {
    console.warn(`DefiLlama: skipped (HTTP ${r.status})`);
    return { byDomain: new Map(), byHandle: new Map() };
  }

  const byDomain = new Map();
  const byHandle = new Map();

  for (const p of r.body || []) {
    const domain = registrableOf(hostOf(p.url || ""));
    const handle = String(p.twitter || "").toLowerCase();

    if (domain && !byDomain.has(domain)) byDomain.set(domain, p);
    if (handle && !byHandle.has(handle)) byHandle.set(handle, p);
  }

  console.log(`DefiLlama: loaded ${byDomain.size} protocols`);

  return { byDomain, byHandle };
}

function auditsFrom(protocol) {
  if (!protocol) return [];

  const links = Array.isArray(protocol.audit_links) ? protocol.audit_links : [];

  return links.filter(Boolean).map((url) => ({
    auditor: hostOf(url) || undefined,
    reportUrl: url,
    scope: undefined,
    status: "confirmed",
    sourceUrl: `https://defillama.com/protocol/${protocol.slug}`,
    sourceLabel: "DefiLlama",
    checkedAt: today(),
  }));
}

/* =========================
   Per-project verification
========================= */

async function verifyProject(project, llama) {
  const checkedAt = today();
  const links = [];
  const signals = [];
  const audits = [];
  const funding = [];
  const contracts = [];

  let alert;

  const website = project.website || "";
  const host = hostOf(website);
  const domain = registrableOf(host);

  if (!website || !host) {
    links.push({
      kind: "website",
      status: "not_found",
      note: "No official website in our sources",
      checkedAt,
    });
  } else {
    const site = await get(website);

    if (!site.ok) {
      links.push({
        kind: "website",
        url: website,
        status: "unverified",
        note: `Site did not respond (${site.status || site.error})`,
        sourceUrl: website,
        sourceLabel: "Site",
        checkedAt,
      });
    } else {
      // A redirect off the declared domain is worth surfacing: it's
      // normal for rebrands, and a red flag for cloned listings.
      const landedOn = registrableOf(hostOf(site.url));
      const redirected = landedOn && landedOn !== domain;

      links.push({
        kind: "website",
        url: site.url,
        status: "confirmed",
        note: redirected ? `Redirects to ${landedOn}` : "Site is reachable",
        sourceUrl: site.url,
        sourceLabel: "Site",
        checkedAt,
      });

      const found = extractSiteLinks(String(site.body));
      const effectiveDomain = landedOn || domain;

      // ---- X ----

      const listedHandle = handleOf(project.x);
      const siteHandle = found.x[0];

      if (siteHandle) {
        const url = `https://x.com/${siteHandle}`;
        const back = await backlinkCheck(url, effectiveDomain);

        const mismatch = Boolean(listedHandle && listedHandle !== siteHandle);

        links.push({
          kind: "x",
          url,
          status: mismatch ? "unverified" : back.status,
          note: mismatch
            ? `Our sources list @${listedHandle}, the site links @${siteHandle}`
            : back.note,
          sourceUrl: site.url,
          sourceLabel: "Site",
          checkedAt,
        });

        signals.push({
          code: "link_mismatch",
          label: mismatch
            ? "The X account on the site differs from the one in our listing"
            : "Site and listing point at the same X account",
          present: mismatch,
          sourceUrl: site.url,
          sourceLabel: "Site",
          checkedAt,
        });
      } else {
        links.push({
          kind: "x",
          url: project.x || undefined,
          status: project.x ? "unverified" : "not_found",
          note: project.x
            ? "Listed by an aggregator, not found on the official site"
            : "No X account found on the official site",
          sourceUrl: project.sourceUrl,
          sourceLabel: project.source,
          checkedAt,
        });
      }

      // ---- Discord / Telegram / docs ----

      for (const [kind, values, listed] of [
        ["discord", found.discord, project.discord],
        ["telegram", found.telegram, project.telegram],
        ["docs", found.docs, project.docs || project.whitepaper],
      ]) {
        const url = values[0] || listed;

        links.push({
          kind,
          url: url || undefined,
          status: values[0] ? "confirmed" : url ? "unverified" : "not_found",
          note: values[0]
            ? "Linked from the official site"
            : url
            ? "From an aggregator listing, not found on the official site"
            : undefined,
          sourceUrl: values[0] ? site.url : project.sourceUrl,
          sourceLabel: values[0] ? "Site" : project.source,
          checkedAt,
        });
      }
    }

    // ---- Domain age ----

    const age = await domainAge(domain);

    if (age.ageDays !== undefined) {
      signals.push({
        code: "domain_very_new",
        label:
          age.ageDays < 30
            ? `Domain registered ${age.ageDays} days ago`
            : `Domain registered ${Math.floor(age.ageDays / 30)} months ago`,
        present: age.ageDays < 30,
        sourceUrl: age.source,
        sourceLabel: "RDAP",
        checkedAt,
      });

      signals.push({
        code: "domain_new",
        label: `Domain age: ${age.ageDays} days`,
        present: age.ageDays < 180,
        sourceUrl: age.source,
        sourceLabel: "RDAP",
        checkedAt,
      });
    }

    // ---- Safe Browsing ----

    const candidates = [website, project.claimUrl].filter(Boolean);
    const sb = await safeBrowsing([...new Set(candidates)]);

    if (sb.checked) {
      const present = sb.hits.length > 0;

      signals.push({
        code: "unsafe_browsing",
        label: present
          ? "Google Safe Browsing flags this site"
          : "Clean in Google Safe Browsing",
        present,
        sourceUrl: "https://transparencyreport.google.com/safe-browsing/search",
        sourceLabel: "Safe Browsing",
        checkedAt,
      });

      if (present) {
        alert = "Google Safe Browsing flags this project's site as dangerous. Do not connect a wallet.";
      }
    }
  }

  // ---- Audits (DefiLlama) ----

  const protocol =
    (domain && llama.byDomain.get(domain)) ||
    (handleOf(project.x) && llama.byHandle.get(handleOf(project.x)));

  const llamaAudits = auditsFrom(protocol);

  if (llamaAudits.length) {
    audits.push(...llamaAudits);
  } else {
    audits.push({
      status: "not_found",
      sourceUrl: "https://defillama.com",
      sourceLabel: "DefiLlama",
      checkedAt,
    });
  }

  signals.push({
    code: "no_audit",
    label: llamaAudits.length
      ? `${llamaAudits.length} public audit report(s) found`
      : "No public audit found",
    present: llamaAudits.length === 0,
    sourceUrl: protocol
      ? `https://defillama.com/protocol/${protocol.slug}`
      : "https://defillama.com",
    sourceLabel: "DefiLlama",
    checkedAt,
  });

  // ---- Contract ----
  //
  // Deliberately not searched for: an address found by guessing is
  // worse than no address at all. Only the manual layer or official
  // docs put an address here; the explorer call then confirms it.

  contracts.push({
    status: "not_found",
    note: "No contract address on file",
    checkedAt,
  });

  // ---- Funding ----
  //
  // Whatever sync already found, carried over with its source. Rounds
  // from CryptoRank/RootData get added by the manual layer for now.

  if (project.funding) {
    funding.push({
      round: "Total raised",
      amountUsd: Number(String(project.funding).replace(/[^0-9.]/g, "")) || undefined,
      sourceUrl: project.sourceUrl,
      sourceLabel: project.source,
      checkedAt,
    });
  }

  return {
    slug: project.slug,
    checkedAt,
    links,
    contracts,
    audits,
    funding,
    signals,
    alert,
  };
}

/* =========================
   Project loading
========================= */

// Same regex trick as scripts/sync.js: this runs under plain Node and
// can't import a .ts module.
async function loadProjects() {
  const content = await fs.readFile(GENERATED, "utf8");
  const projects = [];

  const objectRegex = /\{[^{}]*\}/g;
  let match;

  const field = (block, name) =>
    block.match(new RegExp(`"${name}":\\s*"([^"]*)"`))?.[1] || "";

  while ((match = objectRegex.exec(content))) {
    const block = match[0];
    const slug = field(block, "slug");

    if (!slug) continue;

    projects.push({
      slug,
      name: field(block, "name"),
      website: field(block, "website"),
      x: field(block, "x"),
      discord: field(block, "discord"),
      telegram: field(block, "telegram"),
      docs: field(block, "docs"),
      whitepaper: field(block, "whitepaper"),
      claimUrl: field(block, "claimUrl"),
      funding: field(block, "funding"),
      source: field(block, "source"),
      sourceUrl: field(block, "sourceUrl"),
    });
  }

  return projects;
}

async function loadCache() {
  try {
    return JSON.parse(await fs.readFile(CACHE, "utf8"));
  } catch {
    return { entries: {} };
  }
}

/* =========================
   Run
========================= */

async function run() {
  const projects = await loadProjects();
  const cache = await loadCache();

  console.log(`Verify: ${projects.length} projects in projects.generated.ts`);

  // A project is re-checked when its cache entry is stale or when the
  // links sync found for it have changed since the last check.
  const fingerprint = (p) => [p.website, p.x, p.discord, p.claimUrl].join("|");

  const due = projects
    .filter((p) => {
      const entry = cache.entries[p.slug];

      if (!entry) return true;
      if (entry.fingerprint !== fingerprint(p)) return true;

      return daysSince(entry.checkedAt) > RECHECK_AFTER_DAYS;
    })
    .sort((a, b) => {
      const at = cache.entries[a.slug]?.checkedAt || "";
      const bt = cache.entries[b.slug]?.checkedAt || "";

      return at.localeCompare(bt);
    })
    .slice(0, MAX_PER_RUN);

  console.log(`Verify: ${due.length} due this run (cap ${MAX_PER_RUN})`);

  const llama = await loadDefiLlama();

  const results = new Map(
    Object.entries(cache.entries)
      .filter(([, entry]) => entry.result)
      .map(([slug, entry]) => [slug, entry.result])
  );

  let cursor = 0;

  const worker = async () => {
    while (true) {
      const index = cursor++;

      if (index >= due.length) return;

      const project = due[index];

      console.log(`Verify: ${index + 1}/${due.length} ${project.name || project.slug}`);

      const result = await verifyProject(project, llama);

      results.set(project.slug, result);

      cache.entries[project.slug] = {
        checkedAt: result.checkedAt,
        fingerprint: fingerprint(project),
        result,
      };

      await sleep(300);
    }
  };

  await Promise.all(
    Array.from({ length: Math.min(CONCURRENCY, due.length) }, () => worker())
  );

  // Drop cache entries for projects that no longer exist.
  const live = new Set(projects.map((p) => p.slug));

  for (const slug of Object.keys(cache.entries)) {
    if (!live.has(slug)) {
      delete cache.entries[slug];
      results.delete(slug);
    }
  }

  const output = [...results.values()].sort((a, b) => a.slug.localeCompare(b.slug));

  await fs.writeFile(
    OUT,
    `// AUTO-GENERATED by scripts/verify.js. Do not edit.
// Hand-checked data belongs in data/verification.manual.ts.
import type { ProjectVerification } from "./verification";
import { scoreRisk } from "./verification";

const entries = ${JSON.stringify(output, null, 2)} as Omit<ProjectVerification, "risk">[];

export const generatedVerification: ProjectVerification[] = entries.map((e) => ({
  ...e,
  risk: scoreRisk(e.signals),
}));
`,
    "utf8"
  );

  await fs.writeFile(CACHE, JSON.stringify(cache, null, 2), "utf8");

  const alerts = output.filter((e) => e.alert);

  console.log("");
  console.log("=================================");
  console.log("Droply verification complete");
  console.log("=================================");
  console.log(`Checked this run: ${due.length}`);
  console.log(`Entries on file:  ${output.length}`);
  console.log(`Alerts:           ${alerts.length}`);
  console.log("=================================");

  for (const entry of alerts) {
    console.warn(`ALERT ${entry.slug}: ${entry.alert}`);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  run();
}

export { extractSiteLinks, registrableOf, handleOf, auditsFrom };
