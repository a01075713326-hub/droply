import path from "node:path";
import { fileURLToPath } from "node:url";
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
import fs from "node:fs/promises";

const CR =
  "https://api.cryptorank.io/v2/drophunting/activities?limit=300&sortBy=lastStatusUpdate&sortDirection=DESC";

const AIR_SECTIONS = [
  { url: "https://airdrops.io/speculative/", status: "Potential" },
  { url: "https://airdrops.io/confirmed/", status: "Confirmed" },
];

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

const decode = (v) =>
  String(v || "")
    .replace(/&amp;/g, "&")
    .replace(/&#8217;|&#x27;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&nbsp;/g, " ");

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
      const name =
        x?.coin?.name || x?.name || `Project ${i + 1}`;

      const slug = slugify(x?.coin?.key || name);

      const d = x?.rewardDate || x?.lastStatusUpdate;

      const date = d
        ? new Date(
            Number(d) < 1e10 ? Number(d) * 1000 : Number(d)
          )
            .toISOString()
            .slice(0, 10)
        : "";

      const chain =
        x?.tasks?.flatMap((t) => t?.blockchains || [])?.[0]?.name ||
        "Multiple";

      return {
        id: i + 1,
        slug,
        name,
        symbol: x?.coin?.symbol || "вЂ”",
        chain,
        event: eventCR(x?.reward),
        status: statusCR(x?.status),
        date,
        description: `${name} drop activity tracked from CryptoRank.`,
        funding: x?.coin?.totalRaise
          ? `$${x.coin.totalRaise}`
          : undefined,
        website:
          x?.links?.verify ||
          x?.links?.claim,
        logo:
          x?.coin?.images?.x150 ||
          x?.coin?.images?.native,
        claimUrl:
          x?.links?.claim ||
          x?.links?.verify,
        source: "CryptoRank",
        sourceUrl:
          `https://cryptorank.io/drophunting/${x?.key || slug}`,
      };
    });
  } catch (error) {
    console.warn(
      `CryptoRank: skipped (${error?.message || "request failed"})`
    );

    return [];
  }
}

/* =========================
   Airdrops.io
========================= */

async function airdropsIo() {
  const headers = {
    "User-Agent": "Mozilla/5.0 (compatible; Droply.digital/1.0)",
    "Accept": "text/html,application/xhtml+xml",
  };

  const sleep = (ms) =>
    new Promise((resolve) => setTimeout(resolve, ms));

  const cleanText = (value) =>
    decode(
      String(value || "")
        .replace(/<[^>]+>/g, " ")
        .replace(/\s+/g, " ")
        .trim()
    );

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
      lower.includes("x.com") ||
      lower.includes("twitter.com") ||
      lower.includes("t.me") ||
      lower.includes("telegram") ||
      lower.includes("discord.gg") ||
      lower.includes("facebook.com") ||
      lower.includes("linkedin.com")
    );
  };

  const normalizeChain = (value) => {
    const raw = cleanText(value);

    if (!raw) return "";

    const key = raw
      .toLowerCase()
      .replace(/[\s_-]+/g, "");

    const map = {
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
      ownchain: "OwnChain",
      multiple: "Multiple",
      other: "Other"
    };

    // Anything not in the map still gets Title Case instead of
    // being passed through as-is (avoids raw lowercase values
    // like "hyperliquid" or "other" leaking into the UI).
    return (
      map[key] ||
      raw.replace(/\b\w/g, (c) => c.toUpperCase())
    );
  };

  const normalizeSymbol = (value) => {
    const raw = cleanText(value);

    if (!raw) return "";

    const normalized = raw
      .replace(/\uFFFD/g, "")
      .replace(/[\u0000-\u001F\u007F]/g, "")
      .trim();

    if (!normalized) return "";

    const garbage = [
      "Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р В РІР‚В Р В Р’В Р Р†Р вЂљРЎв„ўР В Р Р‹Р Р†РІР‚С›РЎС›Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р Р‹Р РЋРІвЂћСћ",
      "Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р В РІР‚В Р В Р’В Р Р†Р вЂљРЎв„ўР В Р Р‹Р Р†РІР‚С›РЎС›Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В Р вЂ№Р В Р Р‹Р Р†РІР‚С›РЎС›",
      "-",
      "Р В Р’В Р вЂ™Р’В Р В РІР‚в„ўР вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р вЂ™Р’В Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р В РІР‚В Р В Р’В Р Р†Р вЂљРЎв„ўР В Р Р‹Р Р†РІР‚С›РЎС›Р В Р’В Р Р†Р вЂљРІвЂћСћР В РІР‚в„ўР вЂ™Р’В¬Р В Р’В Р вЂ™Р’В Р В Р’В Р Р†Р вЂљР’В Р В Р’В Р вЂ™Р’В Р В Р вЂ Р В РІР‚С™Р РЋРІвЂћСћР В Р’В Р В РІР‚В Р В Р вЂ Р В РІР‚С™Р РЋРІР‚С”Р В Р Р‹Р РЋРІР‚С”",
      "n/a",
      "na",
      "none",
      "unknown",
      "tbd",
      "tba"
    ];

    if (garbage.includes(normalized.toLowerCase())) {
      return "";
    }

    // Accept normal ASCII tickers only.
    // This also removes broken/mojibake values.
    if (!/^\$?[A-Za-z0-9][A-Za-z0-9._-]{0,19}$/.test(normalized)) {
      return "";
    }

    return normalized.toUpperCase();
  };
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

    return [...match[1].matchAll(
      /<span[^>]*class=["'][^"']*req-pill[^"']*["'][^>]*>([\s\S]*?)<\/span>/gi
    )]
      .map((m) => cleanText(m[1]))
      .filter(Boolean);
  };

  const extractGuideSteps = (html) => {
    const steps = [];

    const re =
      /"@type":"HowToStep"[\s\S]*?"name":"([^"]+)"[\s\S]*?"text":"([^"]+)"/gi;

    let match;

    while ((match = re.exec(html))) {
      const name = cleanText(
        match[1]
          .replace(/\\"/g, '"')
          .replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) =>
            String.fromCharCode(parseInt(hex, 16))
          )
      );

      const text = cleanText(
        match[2]
          .replace(/\\"/g, '"')
          .replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) =>
            String.fromCharCode(parseInt(hex, 16))
          )
      );

      if (name) {
        steps.push(
          text && text !== name
            ? `${name}: ${text}`
            : name
        );
      }
    }

    return steps;
  };

  const extractSocial = (html, type) => {
    let pattern;

    if (type === "telegram") {
      pattern =
        /href=["'](https?:\/\/(?:www\.)?t\.me\/[^"'?#]+)["']/i;
    } else if (type === "discord") {
      pattern =
        /href=["'](https?:\/\/(?:www\.)?discord(?:\.gg|\.com)\/[^"'?#]+)["']/i;
    } else {
      return "";
    }

    return pattern.exec(html)?.[1] || "";
  };

  const extractOverviewLink = (html, label) => {
    const content = extractOverviewItem(html, label);

    return (
      content.match(
        /href=["'](https?:\/\/[^"']+)["']/i
      )?.[1] || ""
    );
  };

  const extractNetwork = (html) => {
    const match = html.match(
      /window\.adioPage\s*=\s*\{[\s\S]*?"airdrop_network"\s*:\s*"([^"]+)"/i
    );

    return cleanText(match?.[1]);
  };

  const extractAirdropStatus = (html) => {
    const match = html.match(
      /window\.adioPage\s*=\s*\{[\s\S]*?"airdrop_status"\s*:\s*"([^"]+)"/i
    );

    return cleanText(match?.[1]);
  };

  const extractAirdropFlag = (html) => {
    const match = html.match(
      /window\.adioPage\s*=\s*\{[\s\S]*?"airdrop_flags"\s*:\s*"([^"]+)"/i
    );

    return cleanText(match?.[1]);
  };

  const extractGuideTotal = (html) => {
    const match = html.match(
      /window\.adioPage\s*=\s*\{[\s\S]*?"guide_steps_total"\s*:\s*(\d+)/i
    );

    return match?.[1] ? Number(match[1]) : 0;
  };

  const extractTicker = (html) => {
    const value = extractOverviewItem(html, "Ticker");
    return normalizeSymbol(value);
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
      content
        .replace(/<a[^>]*>[\s\S]*?<\/a>/gi, "")
        .replace(/<[^>]+>/g, " ")
    );
  };

  const extractOverviewHost = (html, label) => {
    const content = extractOverviewItem(html, label);

    return (
      content.match(
        /data-outbound-host=["']([^"']+)["']/i
      )?.[1] || ""
    );
  };

  // ------------------------------------------------------------
  // 1. Get project cards from /latest/, /upcoming/, /confirmed/
  // ------------------------------------------------------------

  const projects = [];
  const seen = new Set();

  const articleRe =
    /<article\b[^>]*\bproject\b[^>]*>[\s\S]*?<\/article>/gi;

  for (const section of AIR_SECTIONS) {
    const r = await fetch(section.url, {
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/142 Safari/537.36"
      }
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

      const projectSlug =
        block.match(
          /href=["']https?:\/\/airdrops\.io\/([^"'/?#]+)\/?["']/i
        )?.[1];

      if (!projectSlug) continue;

      const slug = slugify(projectSlug);

      if (seen.has(slug)) continue;

      const name = cleanText(
        block.match(
          /<h3[^>]*>\s*([^<]{1,100})\s*<\/h3>/i
        )?.[1]
      );

      if (!name) continue;

      const logo =
        block.match(
          /<img[^>]+data-src=["']([^"']+)["']/i
        )?.[1] ||
        block.match(
          /<img[^>]+src=["'](https?:\/\/[^"']+)["']/i
        )?.[1];

      const statusClass =
        block.match(
          /status-indicator\s+([a-z-]+)/i
        )?.[1]?.toLowerCase();

      // Default to the status implied by which section this
      // card came from (/latest/, /upcoming/, /confirmed/),
      // then refine it if the card itself has a clearer class.
      let status = section.status;

      if (statusClass === "ongoing") {
        status = "Live";
      } else if (
        statusClass === "confirmed" ||
        statusClass === "complete" ||
        statusClass === "completed"
      ) {
        status = "Confirmed";
      } else if (
        statusClass === "upcoming" ||
        statusClass === "future"
      ) {
        status = "Upcoming";
      }

      const outboundHost =
        block.match(
          /data-outbound-host=["']([^"']+)["']/i
        )?.[1];

      const visitPath =
        block.match(
          /href=["'](\/visit\/[^"']+)["']/i
        )?.[1];

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
        description:
          `${name} airdrop listing aggregated from Airdrops.io.`,
        logo,
        source: "Airdrops.io",
        sourceUrl: `https://airdrops.io/${slug}/`,
        claimUrl,
      });

      seen.add(slug);
    }
  }

  console.log(
    `Airdrops.io: found ${projects.length} project cards`
  );

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

      const ticker = extractTicker(page);

      if (ticker) {
        project.symbol = ticker;
      }

      const network = extractNetwork(page);

      if (network) {
        project.chain = normalizeChain(network);
      }

      // --------------------------------------------------------
      // DESCRIPTION
      // --------------------------------------------------------

      const metaDescription =
        cleanText(
          page.match(
            /<meta[^>]+name=["']description["'][^>]+content=["']([^"']+)["']/i
          )?.[1]
        );

      if (metaDescription) {
        project.description = metaDescription.slice(0, 500);
      }
      
      const difficulty =
        extractScoreValue(page, "Difficulty");

      if (difficulty) {
        project.difficulty = difficulty;
      }

      const costToFarm =
        extractScoreValue(page, "Cost to Farm");

      if (costToFarm) {
        project.costToFarm = costToFarm;
      }

      const requirements =
        extractRequirements(page);

      if (requirements.length) {
        project.requirements = requirements;
      }

      const actions =
        extractGuideSteps(page);

      if (actions.length) {
        project.actions = actions;
      }

      const socialTelegram =
        extractSocial(page, "telegram");

      if (socialTelegram) {
        project.telegram = socialTelegram;
      }

      const socialDiscord =
        extractSocial(page, "discord");

      if (socialDiscord) {
        project.discord = socialDiscord;
      }

      const whitepaper =
        extractOverviewLink(page, "Whitepaper");

      if (whitepaper) {
        project.whitepaper = whitepaper;
      }

      const docs =
        extractOverviewLink(page, "Documentation");

      if (docs) {
        project.docs = docs;
      }

      const networkStatus =
        extractAirdropStatus(page);

      // "airdrop_flags" is a comma-separated list (e.g.
      // "confirmed,speculative"), not a single value.
      const flags = extractAirdropFlag(page)
        .split(",")
        .map((f) => f.trim().toLowerCase())
        .filter(Boolean);

      const isConfirmed = flags.includes("confirmed");
      const isSpeculative = flags.includes("speculative");

      // "airdrop_flags" tells us how certain the drop is;
      // "airdrop_status" (ongoing/upcoming) tells us its timing.
      // A confirmed airdrop stays "Confirmed" even while it's
      // actively ongoing вЂ” the confirmed flag wins over timing.
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

      // --------------------------------------------------------
      // WEBSITE
      // --------------------------------------------------------

      const websiteHost =
        extractOverviewHost(page, "Website");

      const websiteText =
        extractOverviewText(page, "Website");

      const websiteCandidate =
        websiteHost || websiteText;

      if (websiteCandidate && !isBadWebsite(websiteCandidate)) {
        project.website = normalizeUrl(websiteCandidate);
      }

      // --------------------------------------------------------
      // TICKER
      // --------------------------------------------------------

            if (ticker) {
        const cleanedTicker = normalizeSymbol(ticker);

        if (cleanedTicker) {
          project.symbol = cleanedTicker;
        }
      }

      // --------------------------------------------------------
      // X / TWITTER
      // --------------------------------------------------------

      const xItem =
        page.match(
          /<li[^>]*>\s*X\s*\(Formerly Twitter\)\s*:\s*([\s\S]*?)<\/li>/i
        )?.[1] || "";

      const xUrl =
        xItem.match(
          /href=["'](https?:\/\/(?:www\.)?(?:x|twitter)\.com\/[^"'?#]+)["']/i
        )?.[1];

      if (
        xUrl &&
        !/\/intent\/|\/share|\/home/i.test(xUrl)
      ) {
        project.x = xUrl;
      }

      // --------------------------------------------------------
      // CHAIN
      // --------------------------------------------------------

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

      if (chain) {
        project.chain = normalizeChain(chain);
      }

      // --------------------------------------------------------
      // EVENT
      // --------------------------------------------------------

      // Do not infer event from arbitrary page text.
      // Keep Airdrop unless a dedicated event label is found.

      const eventMatch =
        page.match(
          /<li[^>]*>\s*(?:Event|Type)\s*:\s*([^<]+)<\/li>/i
        );

      if (eventMatch?.[1]) {
        const eventText =
          cleanText(eventMatch[1]).toLowerCase();

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

      // --------------------------------------------------------
      // DATE
      // --------------------------------------------------------

      // Scan every <li> (icons/tags inside are fine, we strip them),
      // look for one that mentions a date-ish keyword AND contains
      // an ISO-like date (YYYY-MM-DD / YYYY.MM.DD / YYYY/MM/DD).
      const liPattern = /<li[^>]*>([\s\S]*?)<\/li>/gi;
      const dateKeywords =
        /\b(date|deadline|snapshot|tge|claim|ends|airdrop\s*ends)\b/i;
      const isoDatePattern = /\b(20\d{2})[-/.](\d{1,2})[-/.](\d{1,2})\b/;

      let liMatch;
      let rawDate = "";

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

      // fallback: scan whole page text if date was not inside <li>
      if (!rawDate) {
        const pageText = cleanText(page);

        if (
          dateKeywords.test(pageText) &&
          (isoDatePattern.test(pageText) || textDatePattern.test(pageText))
        ) {
          rawDate = pageText;
        }
      }

      if (!rawDate) {
        const directDate = page.match(textDatePattern);

        if (directDate) {
          rawDate = directDate[0];
        }
      }

      if (rawDate) {
        const parsed = rawDate.match(isoDatePattern) || rawDate.match(textDatePattern);

        if (parsed) {
          const year = Number(parsed[1]);
          const month = Number(parsed[2]);
          const day = Number(parsed[3]);

          if (
            year >= 2024 &&
            year <= 2035 &&
            month >= 1 &&
            month <= 12 &&
            day >= 1 &&
            day <= 31
          ) {
            project.date =
              `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
          }
        }
      }
// --------------------------------------------------------
      // FUNDING
      // --------------------------------------------------------

      const fundingMatch =
        page.match(
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

  const workers = Array.from(
    { length: Math.min(5, projects.length) },
    () => worker()
  );

  await Promise.all(workers);

  return projects;
}
/* =========================
   Sync
========================= */

(async () => {
  const [a, b] = await Promise.allSettled([
    cryptoRank(),
    airdropsIo(),
  ]);

  const cryptoRankProjects =
    a.status === "fulfilled"
      ? a.value
      : [];

  const airdropsProjects =
    b.status === "fulfilled"
      ? b.value
      : [];

  const all = [
    ...cryptoRankProjects,
    ...airdropsProjects,
  ];

  const map = new Map();

  for (const p of all) {
    map.set(p.slug, {
      ...map.get(p.slug),
      ...p,
    });
  }

  const projects = [...map.values()].map(
    (p, i) => ({
      ...p,
      id: i + 1,
    })
  );

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
  console.log("=================================");

  if (b.status === "rejected") {
    console.error(
      "Airdrops.io error:",
      b.reason
    );
  }
})();






