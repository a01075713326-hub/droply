import { brandImage } from "@/lib/og";

export const alt = "Droply - crypto airdrop tracker";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image() {
  return brandImage();
}