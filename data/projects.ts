import { generatedProjects } from "./projects.generated";
import { manualProjects } from "./manual-projects";

export type ProjectTask = {
  id?: number;
  title: string;
  status?: string;
  types?: string[];
  startDate?: string;
  endDate?: string;
  isNew?: boolean;
  exclusive?: boolean;
  instructions?: string[];
};
export type Project = {
  id: number;
  slug: string;
  name: string;
  symbol?: string;
  isLive?: boolean;
  chain: string;
  event: "Snapshot" | "TGE" | "Claim" | "Airdrop" | "Points";
  status: "Potential" | "Upcoming" | "Live" | "Confirmed";
  date?: string;
  description: string;
  funding?: string;
  website?: string;
  x?: string;
  logo?: string;
  source?: string;
  sourceUrl?: string;
  claimUrl?: string;

  difficulty?: string;
  costToFarm?: string;
  timeToFarm?: string;
  rewardType?: string;
  rating?: number;
  activityTypes?: string[];
  activityPoints?: number;
  noActiveTask?: boolean;
  isAuthProtected?: boolean;
  checkUrl?: string;
  investorCount?: number;
  topInvestors?: unknown[];
  twitterScore?: number;
  twitterFollowers?: number;
  ecosystems?: string[];
  category?: string;
  distributeDate?: string;
  lifeCycle?: string;
  tasks?: ProjectTask[];
  extraLinks?: { label: string; url: string }[];

  requirements?: string[];
  actions?: string[];
  reward?: string;
  deadline?: string;
  telegram?: string;
  discord?: string;
  whitepaper?: string;
  docs?: string;

  /** ISO timestamp of when this drop was first seen by the sync script. */
  firstSeenAt?: string;
};

const demoProjects: Project[] = [
  {
    id: 1,
    slug: "hyperliquid",
    name: "Hyperliquid",
    symbol: "HYPE",
    chain: "Hyperliquid",
    event: "Snapshot",
    status: "Potential",
    date: "2026-09-30",
    description: "A high-performance perpetual trading ecosystem with an active points and rewards narrative.",
    funding: "—",
    website: "https://hyperliquid.xyz"
  },
  {
    id: 2,
    slug: "dolomite",
    name: "Dolomite",
    symbol: "DOLO",
    chain: "Base",
    event: "Airdrop",
    status: "Upcoming",
    date: "2026-09-25",
    description: "A DeFi money market and trading protocol built around flexible collateral and lending.",
    funding: "$2.5M",
    website: "https://dolomite.io"
  },
  {
    id: 3,
    slug: "megaeth",
    name: "MegaETH",
    symbol: "MEGA",
    chain: "Ethereum",
    event: "Airdrop",
    status: "Potential",
    date: "2026-09-28",
    description: "A high-throughput Ethereum-aligned network with a strong ecosystem and community campaign.",
    funding: "$57M",
    website: "https://megaeth.com"
  },
  {
    id: 4,
    slug: "sonieum",
    name: "Soneium",
    symbol: "SONE",
    chain: "Ethereum",
    event: "TGE",
    status: "Upcoming",
    date: "2026-09-22",
    description: "An Ethereum L2 ecosystem focused on consumer applications and creator experiences.",
    funding: "—",
    website: "https://soneium.org"
  },
  {
    id: 5,
    slug: "aptos",
    name: "Aptos",
    symbol: "APT",
    chain: "Aptos",
    event: "Claim",
    status: "Live",
    date: "2026-09-20",
    description: "A Move-based Layer 1 ecosystem with a broad DeFi and application landscape.",
    funding: "$350M",
    website: "https://aptosfoundation.org"
  },
  {
    id: 6,
    slug: "zksync",
    name: "ZKsync",
    symbol: "ZK",
    chain: "Ethereum",
    event: "Airdrop",
    status: "Upcoming",
    date: "2026-09-18",
    description: "An Ethereum scaling ecosystem using zero-knowledge technology.",
    funding: "$458M",
    website: "https://zksync.io"
  },
  {
    id: 7,
    slug: "blast",
    name: "Blast",
    symbol: "BLAST",
    chain: "Ethereum",
    event: "Points",
    status: "Potential",
    date: "2026-09-15",
    description: "An Ethereum L2 ecosystem with native yield and a points-driven campaign history.",
    funding: "$20M",
    website: "https://blast.io"
  }
];

const baseProjects: Project[] =
  generatedProjects.length ? generatedProjects : demoProjects;

const existingSlugs = new Set(baseProjects.map((p) => p.slug));

export const projects: Project[] = [
  ...baseProjects,
  ...manualProjects.filter((p) => !existingSlugs.has(p.slug)),
];
