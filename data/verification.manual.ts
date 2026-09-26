// Hand-checked data. Wins over data/verification.generated.ts,
// section by section. Never overwritten by any workflow — edit freely.
//
// Rules:
//   - anything marked "confirmed" must carry sourceUrl + checkedAt
//   - leaving a section out means "keep whatever the script found"
//   - to deliberately blank a section, pass [] and list it in `overrides`

import type { ManualVerification } from "./verification";

export const manualVerification: ManualVerification[] = [
  {
    slug: "example-project",
    checkedAt: "2026-09-18",
    links: [
      {
        kind: "website",
        url: "https://example.xyz",
        status: "confirmed",
        note: "Site links to the X account and the account links back",
        sourceUrl: "https://example.xyz",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
      {
        kind: "x",
        url: "https://x.com/exampleproject",
        status: "confirmed",
        sourceUrl: "https://x.com/exampleproject",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
    ],
    contracts: [
      {
        status: "not_found",
        note: "No token contract published yet",
        checkedAt: "2026-09-18",
        sourceLabel: "Manual",
      },
    ],
    audits: [
      {
        auditor: "Example Audits",
        reportUrl: "https://exampleaudits.io/reports/example.pdf",
        date: "2026-04-02",
        scope: "Staking contracts only, commit 8f21c0a",
        status: "confirmed",
        sourceUrl: "https://exampleaudits.io/reports/example.pdf",
        sourceLabel: "Example Audits",
        checkedAt: "2026-09-18",
      },
    ],
    signals: [
      {
        code: "anon_team",
        label: "Team members are named with photos and LinkedIn profiles",
        present: false,
        sourceUrl: "https://example.xyz/team",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
    ],
  },
  {
    slug: "gte",
    checkedAt: "2026-09-24",
    links: [
      {
        kind: "website",
        url: "https://gte.lol/",
        status: "confirmed",
        note: "Site is reachable; currently shows an intro/waitlist page, not the live trading app",
        sourceUrl: "https://gte.lol/",
        sourceLabel: "Site",
        checkedAt: "2026-09-24",
      },
      {
        kind: "x",
        url: "https://x.com/GTE_XYZ",
        status: "unverified",
        note: "Linked from the official site; profile could not be read automatically",
        sourceUrl: "https://gte.lol/",
        sourceLabel: "Site",
        checkedAt: "2026-09-24",
      },
      {
        kind: "discord",
        status: "not_found",
        note: "No Discord link found on the official site",
        checkedAt: "2026-09-24",
        sourceLabel: "Manual",
      },
      {
        kind: "telegram",
        status: "not_found",
        note: "No Telegram link found on the official site",
        checkedAt: "2026-09-24",
        sourceLabel: "Manual",
      },
      {
        kind: "docs",
        status: "not_found",
        note: "No docs link found on the official site",
        checkedAt: "2026-09-24",
        sourceLabel: "Manual",
      },
    ],
    contracts: [
      {
        status: "not_found",
        note: "No token contract published yet",
        checkedAt: "2026-09-24",
        sourceLabel: "Manual",
      },
    ],
  },
  {
    slug: "amadeus",
    checkedAt: "2026-09-24",
    links: [
      {
        kind: "website",
        url: "https://amahub.run/",
        status: "confirmed",
        note: "Site is reachable",
        sourceUrl: "https://amahub.run/",
        sourceLabel: "Site",
        checkedAt: "2026-09-24",
      },
      {
        kind: "x",
        url: "https://x.com/amadeusprotocol",
        status: "unverified",
        note: "Listed in an official press release, not confirmed on the official site itself",
        sourceUrl: "https://www.crypto-reporter.com/newsfeed/amadeus-introduces-worlds-first-thinking-blockchain-turning-wasted-mining-power-into-ai-intelligence-111281/",
        sourceLabel: "Press release",
        checkedAt: "2026-09-24",
      },
      {
        kind: "discord",
        url: "https://discord.gg/Cus2RwrhXB",
        status: "confirmed",
        note: "Linked from the official site",
        sourceUrl: "https://amahub.run/",
        sourceLabel: "Site",
        checkedAt: "2026-09-24",
      },
      {
        kind: "telegram",
        url: "https://t.me/amadeusprotocol",
        status: "unverified",
        note: "Listed in an official press release, not found on the current official site",
        sourceUrl: "https://www.crypto-reporter.com/newsfeed/amadeus-introduces-worlds-first-thinking-blockchain-turning-wasted-mining-power-into-ai-intelligence-111281/",
        sourceLabel: "Press release",
        checkedAt: "2026-09-24",
      },
      {
        kind: "docs",
        url: "https://docs.ama.one",
        status: "confirmed",
        note: "Linked from the official site",
        sourceUrl: "https://amahub.run/",
        sourceLabel: "Site",
        checkedAt: "2026-09-24",
      },
    ],
    contracts: [
      {
        status: "not_found",
        note: "No token contract published yet",
        checkedAt: "2026-09-24",
        sourceLabel: "Manual",
      },
    ],
  },
  {
    slug: "powerx-onewallet",
    checkedAt: "2026-09-25",
    links: [
      {
        kind: "website",
        url: "https://powerx.one/en",
        status: "confirmed",
        note: "Linked from the project's official X bio",
        sourceUrl: "https://x.com/Powerxonewallet",
        sourceLabel: "X bio",
        checkedAt: "2026-09-25",
      },
      {
        kind: "x",
        url: "https://x.com/Powerxonewallet",
        status: "unverified",
        note: "Found via search; profile could not be read automatically for confirmation",
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
      {
        kind: "discord",
        status: "not_found",
        note: "No Discord link found during research",
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
      {
        kind: "telegram",
        status: "unverified",
        note: "Airdrop is run through a Telegram bot per third-party guides; official channel link not independently confirmed",
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
      {
        kind: "docs",
        status: "unverified",
        note: "A Litepaper is referenced by third-party guides; not independently located on the official site",
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
    ],
    contracts: [
      {
        status: "not_found",
        note: "PX1 has not launched (pre-TGE); no live token contract to verify",
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
    ],
    audits: [],
    funding: [],
    signals: [
      {
        code: "anon_team",
        label: "No named team members or public profiles found; only a company name appears in the Litepaper",
        present: true,
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
      {
        code: "no_audit",
        label: "No public smart-contract audit found",
        present: true,
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
      {
        code: "no_contract_source",
        label: "No token contract exists yet (pre-TGE)",
        present: true,
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
    ],
  },
  {
    slug: "laptop-bitvavo",
    checkedAt: "2026-09-25",
    links: [
      {
        kind: "website",
        url: "https://bitvavo.com",
        status: "confirmed",
        note: "Bitvavo's main site is reachable; no dedicated official page describing this specific claim campaign was found",
        sourceUrl: "https://bitvavo.com",
        sourceLabel: "Manual",
        checkedAt: "2026-09-25",
      },
      {
        kind: "x",
        status: "not_found",
        note: "No official Bitvavo post about this claim campaign found",
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
    ],
    contracts: [
      {
        status: "unverified",
        note: "LAPTOP token contract exists on Base but was not independently checked here",
        checkedAt: "2026-09-25",
        sourceLabel: "Manual",
      },
    ],
    audits: [],
    funding: [],
    signals: [],
  },
];
