"use client";

import { useState, type CSSProperties } from "react";

function letters(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (!parts.length) return "?";
  if (parts.length === 1) return parts[0].slice(0, 2).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/** Small project logo. Falls back to initials when there is no logo or it fails to load. */
export default function ProjectLogo({
  src,
  name,
  size = 22,
}: {
  src?: string;
  name: string;
  size?: number;
}) {
  const [failed, setFailed] = useState(false);
  const box: CSSProperties = {
    width: size,
    height: size,
    borderRadius: 6,
    flex: "none",
  };

  if (src && !failed) {
    return (
      <img
        src={src}
        alt=""
        width={size}
        height={size}
        loading="lazy"
        decoding="async"
        onError={() => setFailed(true)}
        style={{ ...box, objectFit: "cover" }}
      />
    );
  }

  return (
    <span
      aria-hidden="true"
      style={{
        ...box,
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        background: "rgba(255, 255, 255, 0.12)",
        fontSize: Math.max(8, Math.round(size * 0.42)),
        fontWeight: 700,
        lineHeight: 1,
      }}
    >
      {letters(name)}
    </span>
  );
}