import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
import fs from "node:fs/promises";

const CR =
  "https://api.cryptorank.io/v2/drophunting/activities?limit=300&sortBy=lastStatusUpdate&sortDirection=DESC";

const AIR_SECTIONS = [
  { url: "https://airdrops.io/speculative/", status: "Potential" },
  { url: "https://airdrops.io/confirmed/", status: "Confirmed" },
];

const AA_URL = "https://airdropalert.com/farm/";

const slugify = (v) =>
  String(v || "project")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "") || "project";

const statusCR = (v) =>
  ({
    CONFIRMED: "Confirmed",
    REWARD_AVAILABLE: "Confirmed",
    DISTRIBUTED: "Confirmed",
    SNAPSHOT: "Live",
    VERIFICATION: "Upcoming",
  }[String(v).toUpperCase()] || "Potential");

const eventCR = (v) => {
  const x = String(v || "").toLowerCase();

  if (x.includes("point")) return "Points";
  if (x.includes("snapshot")) return "Snapshot";
  if (x.includes("claim")) return "Claim";

  return "Airdrop";
};

const NAMED_ENTITIES = {
  amp: "&",
  quot: '"',
  apos: "'",
  lt: "<",
  gt: ">",
  nbsp: " ",
  ndash: "-",
  mdash: "—",
  rarr: "→",
  larr: "←",
  hellip: "…",
  lsquo: "'",
  rsquo: "'",
  ldquo: '"',
  rdquo: '"',
  trade: "™",
  reg: "®",
  copy: "©",
  times: "×",
  deg: "°",
};

const decode = (v) =>
  String(v || "")
    .replace(/&#8217;|&#x27;|&#039;/g, "'")
    // Strip leftover numeric char refs (mostly decorative
    // emoji in card copy, e.g. "&#128506;&#65039;").
    .replace(/&#x[0-9a-f]+;/gi, "")
    .replace(/&#\d+;/g, "")
    // Named refs: map the ones we care about, drop the rest so
    // no raw "&rarr;" ends up in the UI.
    .replace(/&([a-z]+);/gi, (match, name) => {
      const key = name.toLowerCase();

      return key in NAMED_ENTITIES ? NAMED_ENTITIES[key] : "";
    })
    // Done last so a decoded "&amp;lt;" doesn't get re-decoded.
    .replace(/&amp;/g, "&");

/* =========================
   Shared text/field helpers
   (used by both airdrops.io and AirdropAlert parsers)
========================= */

const cleanText = (value) =>
  decode(
    String(value || "")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  );

// Same as cleanText, but turns <a href="URL">label</a> into a
// "[label](URL)" markdown-style link instead of throwing the href
// away. Used for guide-step text so the UI can render real,
// clickable links instead of plain text.
const cleanTextKeepLinks = (value) => {
  const withLinks = String(value || "").replace(
    /<a\b[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi,
    (_, href, inner) => {
      const label = inner
        .replace(/<[^>]+>/g, " ")
        .replace(/\s+/g, " ")
        .trim();

      return label ? `[${label}](${href})` : "";
    }
  );

  return decode(
    withLinks
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  );
};

// Guide steps are stored as "title\u2029body" (a paragraph-separator
// character, not part of any real title/body) so the UI can split
// them apart safely — a plain ": " would break on any title or body
// that itself contains a colon.
const STEP_SEP = "\u2029";

const joinStep = (title, body) => {
  if (!title) return body || "";
  if (!body || body === title) return title;

  return `${title}${STEP_SEP}${body}`;
};

const normalizeUrl = (url) => {
  if (!url) return "";

  const value = url.trim();

  if (!value) return "";

  if (/^https?:\/\//i.test(value)) {
    return value;
  }

  return `https://${value.replace(/^\/+/, "")}`;
};

const isBadWebsite = (url) => {
  if (!url) return true;

  const lower = url.toLowerCase();

  return (
    lower.includes("click.trkreels.com") ||
    lower.includes("airdrops.io") ||
    lower.includes("airdropalert.com") ||
    lower.includes("x.com") ||
    lower.includes("twitter.com") ||
    lower.includes("t.me") ||
    lower.includes("telegram") ||
    lower.includes("discord.gg") ||
    lower.includes("facebook.com") ||
    lower.includes("linkedin.com")
  );
};

const CHAIN_MAP = {
  ethereum: "Ethereum",
  eth: "Ethereum",
  solana: "Solana",
  sol: "Solana",
  base: "Base",
  arbitrum: "Arbitrum",
  arbitrumone: "Arbitrum",
  optimism: "Optimism",
  polygon: "Polygon",
  matic: "Polygon",
  bnb: "BNB Chain",
  bnbchain: "BNB Chain",
  binance: "BNB Chain",
  avalanche: "Avalanche",
  avax: "Avalanche",
  sui: "Sui",
  aptos: "Aptos",
  near: "NEAR",
  ton: "TON",
  tron: "TRON",
  zksync: "zkSync",
  starknet: "Starknet",
  linea: "Linea",
  scroll: "Scroll",
  blast: "Blast",
  mantle: "Mantle",
  mode: "Mode",
  ink: "Ink",
  berachain: "Berachain",
  monad: "Monad",
  robinhood: "Robinhood",
  robinhoodchain: "Robinhood",
  ownchain: "OwnChain",
  hyperliquid: "Hyperliquid",
  megaeth: "MegaETH",
  ronin: "Ronin",
  bitcoin: "Bitcoin",
  btc: "Bitcoin",
  arc: "Arc",
  testnet: "Testnet",
  multiple: "Multiple",
  other: "Other",
};

const normalizeChain = (value) => {
  const raw = cleanText(value);

  if (!raw) return "";

  const key = raw.toLowerCase().replace(/[\s_-]+/g, "");

  // Anything not in the map still gets Title Case instead of
  // being passed through as-is (avoids raw lowercase values
  // like "hyperliquid" or "other" leaking into the UI).
  return CHAIN_MAP[key] || raw.replace(/\b\w/g, (c) => c.toUpperCase());
};

const SYMBOL_GARBAGE = [
  "-",
  "n/a",
  "na",
  "none",
  "unknown",
  "tbd",
  "tba",
];

const normalizeSymbol = (value) => {
  const raw = cleanText(value);

  if (!raw) return "";

  const normalized = raw
    .replace(/\uFFFD/g, "")
    .replace(/[\u0000-\u001F\u007F]/g, "")
    .trim();

  if (!normalized) return "";

  if (SYMBOL_GARBAGE.includes(normalized.toLowerCase())) {
    return "";
  }

  // Accept normal ASCII tickers only.
  // This also removes broken/mojibake values.
  if (!/^\$?[A-Za-z0-9][A-Za-z0-9._-]{0,19}$/.test(normalized)) {
    return "";
  }

  return normalized.toUpperCase();
};

/* =========================
   CryptoRank
========================= */

async function cryptoRank() {
  if (!process.env.CRYPTORANK_API_KEY) {
    console.log("CryptoRank: skipped (API key not configured)");
    return [];
  }

  try {
    const r = await fetch(CR, {
      headers: {
        "X-Api-Key": process.env.CRYPTORANK_API_KEY,
      },
    });

    if (!r.ok) {
      const text = await r.text();

      if (r.status === 403) {
        console.warn(
          "CryptoRank: skipped (Drophunting endpoint is not available on the current API plan)"
        );
      } else {
        console.warn(`CryptoRank: skipped (HTTP ${r.status})`);
        console.warn(text.slice(0, 300));
      }

      return [];
    }

    const j = await r.json();

    return (j.data || []).map((x, i) => {
      const name = x?.coin?.name || x?.name || `Project ${i + 1}`;

      const slug = slugify(x?.coin?.key || name);

      const d = x?.rewardDate || x?.lastStatusUpdate;

      const date = d
        ? new Date(Number(d) < 1e10 ? Number(d) * 1000 : Number(d))
            .toISOString()
            .slice(0, 10)
        : "";

      const chain =
        x?.tasks?.flatMap((t) => t?.blockchains || [])?.[0]?.name || "Multiple";

      return {
        id: i + 1,
        slug,
        name,
        symbol: normalizeSymbol(x?.coin?.symbol),
        chain: normalizeChain(chain) || "Multiple",
        event: eventCR(x?.reward),
        status: statusCR(x?.status),
        date,
        description: `${name} drop activity tracked from CryptoRank.`,
        funding: x?.coin?.totalRaise ? `$${x.coin.totalRaise}` : undefined,
        website: x?.links?.verify || x?.links?.claim,
        logo: x?.coin?.images?.x150 || x?.coin?.images?.native,
        claimUrl: x?.links?.claim || x?.links?.verify,
        source: "CryptoRank",
        sourceUrl: `https://cryptorank.io/drophunting/${x?.key || slug}`,
      };
    });
  } catch (error) {
    console.warn(`CryptoRank: skipped (${error?.message || "request failed"})`);

    return [];
  }
}

/* =========================
   Airdrops.io
========================= */

async function airdropsIo() {
  const headers = {
    "User-Agent": "Mozilla/5.0 (compatible; Droply.digital/1.0)",
    Accept: "text/html,application/xhtml+xml",
  };

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  const fetchPage = async (url) => {
    try {
      const r = await fetch(url, { headers });

      if (!r.ok) {
        console.log(`Airdrops.io: ${r.status} ${url}`);
        return "";
      }

      return await r.text();
    } catch {
      console.log(`Airdrops.io: fetch failed ${url}`);
      return "";
    }
  };

  const extractOverviewItem = (html, label) => {
    const re = new RegExp(
      `<li[^>]*>\\s*${label}\\s*:\\s*([\\s\\S]*?)<\\/li>`,
      "i"
    );

    return re.exec(html)?.[1] || "";
  };

  const extractOverviewText = (html, label) => {
    const content = extractOverviewItem(html, label);

    return cleanText(
      content.replace(/<a[^>]*>[\s\S]*?<\/a>/gi, "").replace(/<[^>]+>/g, " ")
    );
  };

  const extractOverviewHost = (html, label) => {
    const content = extractOverviewItem(html, label);

    return content.match(/data-outbound-host=["']([^"']+)["']/i)?.[1] || "";
  };

  const extractOverviewLink = (html, label) => {
    const content = extractOverviewItem(html, label);

    return content.match(/href=["'](https?:\/\/[^"']+)["']/i)?.[1] || "";
  };

  const extractTicker = (html) => normalizeSymbol(extractOverviewItem(html, "Ticker"));

  const extractScoreValue = (html, title) => {
    const re = new RegExp(
      `<h2[^>]*>\\s*${title}\\s*<\\/h2>[\\s\\S]*?<span[^>]*class=["'][^"']*sv-label[^"']*["'][^>]*>\\s*([^<]+)\\s*<\\/span>`,
      "i"
    );

    return cleanText(re.exec(html)?.[1] || "");
  };

  const extractRequirements = (html) => {
    const match = html.match(
      /<div[^>]*class=["'][^"']*airdrop-req[^"']*["'][^>]*>[\s\S]*?<div[^>]*class=["'][^"']*req-pills[^"']*["'][^>]*>([\s\S]*?)<\/div>/i
    );

    if (!match?.[1]) return [];

    return [
      ...match[1].matchAll(
        /<span[^>]*class=["'][^"']*req-pill[^"']*["'][^>]*>([\s\S]*?)<\/span>/gi
      ),
    ]
      .map((m) => cleanText(m[1]))
      .filter(Boolean);
  };

  const unescapeJson = (value) =>
    String(value)
      .replace(/\\\//g, "/")
      .replace(/\\"/g, '"')
      .replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) =>
        String.fromCharCode(parseInt(hex, 16))
      );

  const extractGuideSteps = (html) => {
    const steps = [];

    const re =
      /"@type":"HowToStep"[\s\S]*?"name":"([^"]+)"[\s\S]*?"text":"([^"]+)"/gi;

    let match;

    while ((match = re.exec(html))) {
      // The HowToStep JSON-LD is usually plain text (no <a> tags),
      // but run it through the link-preserving cleaner anyway in
      // case a page ever embeds one.
      const name = cleanTextKeepLinks(unescapeJson(match[1]));
      const text = cleanTextKeepLinks(unescapeJson(match[2]));

      if (name) {
        steps.push(joinStep(name, text));
      }
    }

    return steps;
  };

  const extractSocial = (html, type) => {
    let pattern;

    if (type === "telegram") {
      pattern = /href=["'](https?:\/\/(?:www\.)?t\.me\/[^"'?#]+)["']/i;
    } else if (type === "discord") {
      pattern =
        /href=["'](https?:\/\/(?:www\.)?discord(?:\.gg|\.com)\/[^"'?#]+)["']/i;
    } else {
      return "";
    }

    return pattern.exec(html)?.[1] || "";
  };

  const extractAdioField = (html, field) => {
    const re = new RegExp(
      `window\\.adioPage\\s*=\\s*\\{[\\s\\S]*?"${field}"\\s*:\\s*"([^"]+)"`,
      "i"
    );

    return cleanText(re.exec(html)?.[1]);
  };

  // ------------------------------------------------------------
  // 1. Get project cards from the listing sections
  // ------------------------------------------------------------

  const projects = [];
  const seen = new Set();

  const articleRe = /<article\b[^>]*\bproject\b[^>]*>[\s\S]*?<\/article>/gi;

  for (const section of AIR_SECTIONS) {
    const r = await fetch(section.url, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/142 Safari/537.36",
      },
    });

    if (!r.ok) {
      console.log(`Airdrops.io: ${r.status} ${section.url}`);
      continue;
    }

    const html = await r.text();

    let article;

    articleRe.lastIndex = 0;

    while ((article = articleRe.exec(html))) {
      const block = article[0];

      const projectSlug = block.match(
        /href=["']https?:\/\/airdrops\.io\/([^"'/?#]+)\/?["']/i
      )?.[1];

      if (!projectSlug) continue;

      const slug = slugify(projectSlug);

      if (seen.has(slug)) continue;

      const name = cleanText(
        block.match(/<h3[^>]*>\s*([^<]{1,100})\s*<\/h3>/i)?.[1]
      );

      if (!name) continue;

      const logo =
        block.match(/<img[^>]+data-src=["']([^"']+)["']/i)?.[1] ||
        block.match(/<img[^>]+src=["'](https?:\/\/[^"']+)["']/i)?.[1];

      const statusClass = block
        .match(/status-indicator\s+([a-z-]+)/i)?.[1]
        ?.toLowerCase();

      // Default to the status implied by which section this card
      // came from, then refine it if the card has a clearer class.
      let status = section.status;

      if (statusClass === "ongoing") {
        status = "Live";
      } else if (
        statusClass === "confirmed" ||
        statusClass === "complete" ||
        statusClass === "completed"
      ) {
        status = "Confirmed";
      } else if (statusClass === "upcoming" || statusClass === "future") {
        status = "Upcoming";
      }

      const outboundHost = block.match(
        /data-outbound-host=["']([^"']+)["']/i
      )?.[1];

      const visitPath = block.match(/href=["'](\/visit\/[^"']+)["']/i)?.[1];

      const claimUrl = outboundHost
        ? `https://${outboundHost}`
        : visitPath
        ? `https://airdrops.io${visitPath}`
        : `https://airdrops.io/${slug}/`;

      projects.push({
        id: projects.length + 1,
        slug,
        name,
        symbol: "",
        chain: "Multiple",
        event: "Airdrop",
        status,
        date: "",
        description: `${name} airdrop listing aggregated from Airdrops.io.`,
        logo,
        source: "Airdrops.io",
        sourceUrl: `https://airdrops.io/${slug}/`,
        claimUrl,
      });

      seen.add(slug);
    }
  }

  console.log(`Airdrops.io: found ${projects.length} project cards`);

  // ------------------------------------------------------------
  // 2. Parse project pages
  // ------------------------------------------------------------

  let cursor = 0;

  const worker = async () => {
    while (true) {
      const index = cursor++;

      if (index >= projects.length) return;

      const project = projects[index];

      console.log(
        `Airdrops.io: parsing ${index + 1}/${projects.length} ${project.name}`
      );

      const page = await fetchPage(project.sourceUrl);

      if (!page) {
        await sleep(200);
        continue;
      }

      // ---- TICKER ----

      const ticker = extractTicker(page);

      if (ticker) {
        project.symbol = ticker;
      }

      // ---- DESCRIPTION ----

      const metaDescription = cleanText(
        page.match(
          /<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i
        )?.[1]
      );

      if (metaDescription) {
        project.description = metaDescription.slice(0, 500);
      }

      const difficulty = extractScoreValue(page, "Difficulty");

      if (difficulty) {
        project.difficulty = difficulty;
      }

      const costToFarm = extractScoreValue(page, "Cost to Farm");

      if (costToFarm) {
        project.costToFarm = costToFarm;
      }

      const requirements = extractRequirements(page);

      if (requirements.length) {
        project.requirements = requirements;
      }

      const actions = extractGuideSteps(page);

      if (actions.length) {
        project.actions = actions;
      }

      const socialTelegram = extractSocial(page, "telegram");

      if (socialTelegram) {
        project.telegram = socialTelegram;
      }

      const socialDiscord = extractSocial(page, "discord");

      if (socialDiscord) {
        project.discord = socialDiscord;
      }

      const whitepaper = extractOverviewLink(page, "Whitepaper");

      if (whitepaper) {
        project.whitepaper = whitepaper;
      }

      const docs = extractOverviewLink(page, "Documentation");

      if (docs) {
        project.docs = docs;
      }

      // ---- STATUS ----

      const networkStatus = extractAdioField(page, "airdrop_status");

      // "airdrop_flags" is a comma-separated list (e.g.
      // "confirmed,speculative"), not a single value.
      const flags = extractAdioField(page, "airdrop_flags")
        .split(",")
        .map((f) => f.trim().toLowerCase())
        .filter(Boolean);

      const isConfirmed = flags.includes("confirmed");
      const isSpeculative = flags.includes("speculative");

      // "airdrop_flags" tells us how certain the drop is;
      // "airdrop_status" (ongoing/upcoming) tells us its timing.
      // A confirmed airdrop stays "Confirmed" even while it's
      // actively ongoing — the confirmed flag wins over timing.
      if (isConfirmed) {
        project.status = "Confirmed";
      } else if (isSpeculative) {
        project.status = "Potential";
      } else if (networkStatus === "ongoing") {
        project.status = "Live";
      } else if (networkStatus === "upcoming") {
        project.status = "Upcoming";
      }

      if (isSpeculative) {
        project.event = "Airdrop";
      }

      // ---- WEBSITE ----

      const websiteCandidate =
        extractOverviewHost(page, "Website") ||
        extractOverviewText(page, "Website");

      if (websiteCandidate && !isBadWebsite(websiteCandidate)) {
        project.website = normalizeUrl(websiteCandidate);
      }

      // ---- X / TWITTER ----

      const xItem =
        page.match(
          /<li[^>]*>\s*X\s*\(Formerly Twitter\)\s*:\s*([\s\S]*?)<\/li>/i
        )?.[1] || "";

      const xUrl = xItem.match(
        /href=["'](https?:\/\/(?:www\.)?(?:x|twitter)\.com\/[^"'?#]+)["']/i
      )?.[1];

      if (xUrl && !/\/intent\/|\/share|\/home/i.test(xUrl)) {
        project.x = xUrl;
      }

      // ---- CHAIN ----

      const networkField = extractAdioField(page, "airdrop_network");

      const chainPatterns = [
        /<li[^>]*>\s*Chain\s*:\s*([\s\S]*?)<\/li>/i,
        /<li[^>]*>\s*Blockchain\s*:\s*([\s\S]*?)<\/li>/i,
        /<li[^>]*>\s*Network\s*:\s*([\s\S]*?)<\/li>/i,
      ];

      let chain = "";

      for (const pattern of chainPatterns) {
        const match = page.match(pattern);

        if (match?.[1]) {
          chain = cleanText(match[1]);
          break;
        }
      }

      const resolvedChain = chain || networkField;

      if (resolvedChain) {
        project.chain = normalizeChain(resolvedChain);
      }

      // ---- EVENT ----

      // Do not infer event from arbitrary page text.
      // Keep Airdrop unless a dedicated event label is found.

      const eventMatch = page.match(
        /<li[^>]*>\s*(?:Event|Type)\s*:\s*([^<]+)<\/li>/i
      );

      if (eventMatch?.[1]) {
        const eventText = cleanText(eventMatch[1]).toLowerCase();

        if (eventText.includes("snapshot")) {
          project.event = "Snapshot";
        } else if (
          eventText.includes("tge") ||
          eventText.includes("token generation")
        ) {
          project.event = "TGE";
        } else if (eventText.includes("claim")) {
          project.event = "Claim";
        } else if (eventText.includes("point")) {
          project.event = "Points";
        } else {
          project.event = "Airdrop";
        }
      } else {
        project.event = "Airdrop";
      }

      // ---- DATE ----

      // Scan every <li> (icons/tags inside are fine, we strip them),
      // look for one that mentions a date-ish keyword AND contains
      // a parseable date.
      const liPattern = /<li[^>]*>([\s\S]*?)<\/li>/gi;

      const dateKeywords =
        /\b(date|deadline|snapshot|tge|claim|ends|airdrop\s*ends)\b/i;

      const isoDatePattern = /\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b/;

      const textDatePattern =
        /\b(January|February|March|April|May|June|July|August|September|October|November|December|Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}(?:st|nd|rd|th)?,?\s+\d{4}\b/i;

      let liMatch;
      let rawDate = "";

      liPattern.lastIndex = 0;

      while ((liMatch = liPattern.exec(page)) !== null) {
        const liText = cleanText(liMatch[1]);

        if (
          dateKeywords.test(liText) &&
          (isoDatePattern.test(liText) || textDatePattern.test(liText))
        ) {
          rawDate = liText;
          break;
        }
      }

      // Fallback: a bare date anywhere on the page.
      if (!rawDate) {
        const directIso = page.match(isoDatePattern);
        const directText = page.match(textDatePattern);

        rawDate = directIso?.[0] || directText?.[0] || "";
      }

      if (rawDate) {
        const iso = rawDate.match(isoDatePattern);
        const text = !iso ? rawDate.match(textDatePattern) : null;

        let year, month, day;

        if (iso) {
          year = Number(iso[1]);
          month = Number(iso[2]);
          day = Number(iso[3]);
        } else if (text) {
          const months = {
            january: 1, february: 2, march: 3, april: 4,
            may: 5, june: 6, july: 7, august: 8,
            september: 9, october: 10, november: 11, december: 12,
            jan: 1, feb: 2, mar: 3, apr: 4, jun: 6,
            jul: 7, aug: 8, sep: 9, oct: 10, nov: 11, dec: 12,
          };

          const parts = text[0].match(
            /([A-Za-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})/
          );

          if (parts) {
            month = months[parts[1].toLowerCase()];
            day = Number(parts[2]);
            year = Number(parts[3]);
          }
        }

        if (
          year >= 2024 &&
          year <= 2035 &&
          month >= 1 &&
          month <= 12 &&
          day >= 1 &&
          day <= 31
        ) {
          project.date = `${year}-${String(month).padStart(2, "0")}-${String(
            day
          ).padStart(2, "0")}`;
        }
      }

      // ---- FUNDING ----

      const fundingMatch = page.match(
        /<(?:li|div|p)[^>]*>\s*(?:Funding|Raised|Total Funding)\s*:\s*([^<]+)/i
      );

      if (fundingMatch?.[1]) {
        const funding = cleanText(fundingMatch[1]);

        if (/\$[\d.,]+\s*[KMB]?/i.test(funding)) {
          project.funding = funding;
        }
      }

      await sleep(200);
    }
  };

  const workers = Array.from({ length: Math.min(5, projects.length) }, () =>
    worker()
  );

  await Promise.all(workers);

  return projects;
}

/* =========================
   AirdropAlert
========================= */

export function parseAirdropAlert(html) {
  // Only a couple of card labels tell us anything about status;
  // everything else stays at the default.
  const LABEL_STATUS = {
    verified: "Confirmed",
    new: "Upcoming",
    testnet: "Upcoming",
  };

  const MONTHS = {
    jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6,
    jul: 7, aug: 8, sep: 9, sept: 9, oct: 10, nov: 11, dec: 12,
  };

  // Cards aren't individually closed in a way that's easy to match
  // with a single regex, so slice the page between the start of one
  // card and the start of the next instead.
  const cardStartRe = /<div class="row card card-item card-anchor/g;
  const starts = [];
  let startMatch;

  while ((startMatch = cardStartRe.exec(html))) {
    starts.push(startMatch.index);
  }

  const projects = [];
  const seen = new Set();

  for (let i = 0; i < starts.length; i++) {
    const block = html.slice(starts[i], starts[i + 1] ?? starts[i] + 6000);

    const slugSource = block.match(
      /data-href=["']https?:\/\/airdropalert\.com\/airdrops\/([^"'/?#]+)\/?["']/i
    )?.[1];

    if (!slugSource) continue;

    const slug = slugify(slugSource);

    if (seen.has(slug)) continue;

    const name = cleanText(
      block.match(/<h4[^>]*class=["']title["'][^>]*>([\s\S]*?)<\/h4>/i)?.[1]
    );

    if (!name) continue;

    const logo = block.match(
      /<div class="logo">[\s\S]*?<img[^>]+src=["']([^"']+)["']/i
    )?.[1];

    const chainTooltip = block.match(
      /class="blockchain-logo"\s+tooltip=["']([^"']+)["']/i
    )?.[1];

    const label = cleanText(
      block.match(/data-ribbon=["']([^"']+)["']/i)?.[1]
    ).toLowerCase();

    // Footer copy is two "amount" / "approx" marketing pairs,
    // e.g. "Treasure Hunt" / "Added Sept 16th". Not structured
    // data, but useful for the description and sometimes a date.
    const pairs = [
      ...block.matchAll(
        /<div class="amount">\s*([\s\S]*?)<\/div>\s*<div class="approx">\s*([\s\S]*?)<\/div>/gi
      ),
    ].map(([, a, b]) => [cleanText(a), cleanText(b)]);

    const footerText = pairs
      .map(([a, b]) => [a, b].filter(Boolean).join(" — "))
      .filter(Boolean)
      .join(". ");

    const footerLower = footerText.toLowerCase();

    let event = "Airdrop";

    if (footerLower.includes("snapshot")) {
      event = "Snapshot";
    } else if (
      footerLower.includes("tge") ||
      footerLower.includes("token generation")
    ) {
      event = "TGE";
    } else if (footerLower.includes("claim")) {
      event = "Claim";
    } else if (/\bpoints?\b|\bxp\b/.test(footerLower)) {
      event = "Points";
    }

    let date = "";

    const dateMatch = footerText.match(
      /\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?\b/i
    );

    if (dateMatch) {
      const month = MONTHS[dateMatch[1].toLowerCase()];
      const day = Number(dateMatch[2]);
      const year = new Date().getFullYear();

      if (month && day >= 1 && day <= 31) {
        date = `${year}-${String(month).padStart(2, "0")}-${String(
          day
        ).padStart(2, "0")}`;
      }
    }

    const sourceUrl = `https://airdropalert.com/airdrops/${slug}/`;

    projects.push({
      id: projects.length + 1,
      slug,
      name,
      symbol: "",
      chain: chainTooltip ? normalizeChain(chainTooltip) : "Multiple",
      event,
      status: LABEL_STATUS[label] || "Potential",
      date,
      description:
        footerText || `${name} airdrop listing aggregated from AirdropAlert.`,
      logo,
      source: "AirdropAlert",
      sourceUrl,
      claimUrl: sourceUrl,
    });

    seen.add(slug);
  }

  return projects;
}

async function airdropAlert() {
  const headers = {
    "User-Agent":
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/142 Safari/537.36",
    Accept: "text/html,application/xhtml+xml",
  };

  const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

  const fetchPage = async (url) => {
    try {
      const r = await fetch(url, { headers });

      if (!r.ok) {
        console.log(`AirdropAlert: ${r.status} ${url}`);
        return "";
      }

      return await r.text();
    } catch {
      console.log(`AirdropAlert: fetch failed ${url}`);
      return "";
    }
  };

  const unescapeJson = (value) =>
    String(value)
      .replace(/\\\//g, "/")
      .replace(/\\"/g, '"')
      .replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) =>
        String.fromCharCode(parseInt(hex, 16))
      );

  // Project pages show two "btn btn-project-website" buttons
  // (Website + Whitepaper) sharing the same class, so we pick the
  // one whose own label says "Website".
  const extractAAWebsite = (html) => {
    const buttons = [
      ...html.matchAll(
        /<a\s+href=["']([^"']+)["'][^>]*class=["']btn btn-project-website["'][^>]*>\s*([^<]+?)\s*<\/a>/gi
      ),
    ];

    const websiteButton = buttons.find(
      ([, , label]) => cleanText(label).toLowerCase() === "website"
    );

    return websiteButton?.[1] || "";
  };

  // The real project description lives in the page's own Yoast
  // "WebPage" schema block, not the /farm/ listing footer text.
  const extractAADescription = (html) => {
    const match = html.match(
      /"@type":"WebPage"[\s\S]*?"description":"([^"]+)"/i
    );

    return cleanText(unescapeJson(match?.[1] || ""));
  };

  const extractAASocial = (html, iconClass) => {
    const re = new RegExp(
      `<a\\s+href=["'](https?:\\/\\/[^"']+)["'][^>]*class=["']social-item["'][^>]*>\\s*<span[^>]*class=["']${iconClass}["']`,
      "i"
    );

    return re.exec(html)?.[1] || "";
  };

  const extractAAGuideSteps = (html) => {
    const stepsBlock = html.match(
      /<ol[^>]*class=["']step-list["'][^>]*>([\s\S]*?)<\/ol>/i
    )?.[1];

    if (!stepsBlock) return [];

    return [...stepsBlock.matchAll(/<li[^>]*>([\s\S]*?)<\/li>/gi)]
      .map(([, block]) => {
        const title = cleanText(
          block.match(/<h3[^>]*>([\s\S]*?)<\/h3>/i)?.[1]
        );
        // These <li> blocks have real <a href> links in the body
        // (Galxe campaigns, Discord invites, etc.) — keep them as
        // "[label](url)" instead of stripping them.
        const body = cleanTextKeepLinks(
          block.replace(/<h3[^>]*>[\s\S]*?<\/h3>/i, "")
        );

        return joinStep(title, body);
      })
      .filter(Boolean);
  };

  try {
    const r = await fetch(AA_URL, { headers });

    if (!r.ok) {
      console.log(`AirdropAlert: ${r.status} ${AA_URL}`);
      return [];
    }

    const projects = parseAirdropAlert(await r.text());

    console.log(`AirdropAlert: found ${projects.length} project cards`);

    // ------------------------------------------------------------
    // Visit each project's own page for the real website/description
    // instead of settling for the /farm/ listing card.
    // ------------------------------------------------------------

    let cursor = 0;

    const worker = async () => {
      while (true) {
        const index = cursor++;

        if (index >= projects.length) return;

        const project = projects[index];

        console.log(
          `AirdropAlert: parsing ${index + 1}/${projects.length} ${project.name}`
        );

        const page = await fetchPage(project.sourceUrl);

        if (!page) {
          await sleep(200);
          continue;
        }

        // ---- WEBSITE / CLAIM URL ----
        // sourceUrl (the AirdropAlert page, for "Source:" / "View
        // calendar") stays untouched; only claimUrl moves off-site.

        const website = extractAAWebsite(page);

        if (website && !isBadWebsite(website)) {
          project.website = normalizeUrl(website);
          project.claimUrl = project.website;
        }

        // ---- DESCRIPTION ----

        const description = extractAADescription(page);

        if (description) {
          project.description = description.slice(0, 500);
        }

        // ---- SOCIALS ----

        const telegram = extractAASocial(page, "telegram-icon");

        if (telegram) {
          project.telegram = telegram;
        }

        const discordUrl = extractAASocial(page, "discord-icon");

        if (discordUrl) {
          project.discord = discordUrl;
        }

        const xUrl = extractAASocial(page, "twitter-icon");

        if (xUrl) {
          project.x = xUrl;
        }

        // ---- GUIDE STEPS ----

        const actions = extractAAGuideSteps(page);

        if (actions.length) {
          project.actions = actions;
        }

        await sleep(200);
      }
    };

    const workers = Array.from({ length: Math.min(5, projects.length) }, () =>
      worker()
    );

    await Promise.all(workers);

    return projects;
  } catch (error) {
    console.warn(
      `AirdropAlert: skipped (${error?.message || "request failed"})`
    );

    return [];
  }
}

/* =========================
   Sync
========================= */

async function sync() {
  const [a, b, c] = await Promise.allSettled([
    cryptoRank(),
    airdropsIo(),
    airdropAlert(),
  ]);

  const cryptoRankProjects = a.status === "fulfilled" ? a.value : [];
  const airdropsProjects = b.status === "fulfilled" ? b.value : [];
  const airdropAlertProjects = c.status === "fulfilled" ? c.value : [];

  const all = [
    ...cryptoRankProjects,
    ...airdropsProjects,
    ...airdropAlertProjects,
  ];

  const map = new Map();

  for (const p of all) {
    const prev = map.get(p.slug) || {};

    // Later sources must not overwrite good values with empty ones.
    const merged = { ...prev };

    for (const [key, value] of Object.entries(p)) {
      if (value === undefined || value === null || value === "") continue;
      if (key === "id") continue;

      merged[key] = value;
    }

    map.set(p.slug, merged);
  }

  const projects = [...map.values()].map((p, i) => ({ ...p, id: i + 1 }));

  await fs.writeFile(
    path.join(__dirname, "..", "data", "projects.generated.ts"),
    `// AUTO-GENERATED. Do not edit.
import type { Project } from "./projects";

export const generatedProjects: Project[] = ${JSON.stringify(
      projects,
      null,
      2
    )};
`,
    "utf8"
  );

  console.log("");
  console.log("=================================");
  console.log("Droply sync complete");
  console.log("=================================");
  console.log(`Total projects: ${projects.length}`);
  console.log(`CryptoRank:     ${cryptoRankProjects.length}`);
  console.log(`Airdrops.io:    ${airdropsProjects.length}`);
  console.log(`AirdropAlert:   ${airdropAlertProjects.length}`);
  console.log("=================================");

  if (b.status === "rejected") {
    console.error("Airdrops.io error:", b.reason);
  }

  if (c.status === "rejected") {
    console.error("AirdropAlert error:", c.reason);
  }
}

// Only run the sync when this file is executed directly,
// so the parsers can be imported by tests.
// Uses pathToFileURL instead of a manual "file://" string because
// on Windows process.argv[1] has backslashes and import.meta.url
// has forward slashes / percent-encoding, so a raw string compare
// (like `file://${process.argv[1]}`) never matches there.
if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  sync();
}
