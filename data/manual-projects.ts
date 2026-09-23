import type { Project } from "./projects";

/** Hand-added projects that live outside sync.js. sync.js never touches this file,
    so these entries survive every sync run. Add id values that won't collide with
    generated projects — using a high offset (900000+) keeps this safe. */
export const manualProjects: Project[] = [
  {
    id: 900001,
    slug: "gte",
    name: "GTE",
    symbol: "GTE",
    chain: "MegaETH",
    event: "Airdrop",
    status: "Potential",
    date: "2026-09-23",
    description: "GTE is a decentralized trading venue on MegaETH that unifies a central limit order book, an AMM and a token launchpad in one on-chain platform, aiming to rival Hyperliquid on speed.",
    funding: "$25M",
    website: "https://gte.xyz",
    logo: "https://images.cryptorank.io/coins/150x150.gte1737044153334.png",
    x: "https://x.com/GTE_XYZ",
    source: "Manual",
    category: "DeFi",
    requirements: ["Trading activity"],
    actions: [
      "Sign up and connect a wallet at gte.xyz",
      "Trade on the spot or perpetual order book to build volume",
      "No official token or airdrop confirmed yet — this is a potential future reward, not a guaranteed one"
    ]
  },
  {
    id: 900002,
    slug: "amadeus",
    name: "Amadeus",
    symbol: "AMA",
    chain: "Multiple",
    event: "Airdrop",
    status: "Potential",
    date: "2026-09-23",
    description: "Amadeus Protocol is an open-source blockchain that replaces traditional mining with a useful proof-of-work model, where mining also trains AI models. The AMA token has a 1B max supply.",
    funding: "—",
    website: "https://ama.one",
    logo: "https://ama.one/logos/ama-logo.png",
    source: "Manual",
    category: "AI",
    requirements: ["Mining participation"],
    actions: [
      "Follow the Amadeus Protocol validator/mining setup on the official site",
      "Join the community Discord/Telegram for updates on the AI tool grants program",
      "No official token distribution schedule confirmed — treat as speculative"
    ]
  }
];
