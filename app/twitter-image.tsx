import { brandImage } from "@/lib/og";

export const alt = "Droply \u2014 Track what's dropping.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function Image() {
  return brandImage();
}