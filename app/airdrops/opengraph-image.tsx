import { listImage } from "@/lib/og";

export const alt = "Droply - All Crypto Airdrops";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image() {
  return listImage(
    "AIRDROP TRACKER",
    "All Crypto Airdrops",
    "Snapshots, TGE dates, claims and airdrop events, tracked automatically."
  );
}