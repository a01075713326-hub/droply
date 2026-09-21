import type { CSSProperties } from "react";
import { chainSlug } from "@/lib/chain-slug";

/**
 * Chain logo. Works in server and client components.
 * Pass either `slug` (hub slug) or the raw chain name via `chain` / `name`.
 * Renders nothing for values that are not a real chain (Multiple, Other, ...).
 */
export default function ChainIcon({
  slug,
  name,
  chain,
  size = 16,
  inline = false,
}: {
  slug?: string;
  name?: string;
  chain?: string;
  size?: number;
  inline?: boolean;
}) {
  const s = slug || chainSlug(chain ?? name);
  if (!s) return null;

  const style: CSSProperties = {
    width: size,
    height: size,
    borderRadius: "50%",
    flex: "none",
    objectFit: "contain",
  };
  if (inline) {
    style.verticalAlign = "middle";
    style.marginRight = 6;
  }

  return (
    <img
      src={`/chain-icon/${s}`}
      alt=""
      width={size}
      height={size}
      loading="lazy"
      decoding="async"
      style={style}
    />
  );
}