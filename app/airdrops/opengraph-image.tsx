import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "Droply — All Airdrops";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default async function Image() {
  return new ImageResponse(
    (
      <div
        style={{
          width: "100%",
          height: "100%",
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "flex-start",
          padding: "80px",
          background:
            "radial-gradient(circle at 20% 20%, #2a1a4a 0%, #120a24 45%, #0a0714 100%)",
          fontFamily: "sans-serif",
        }}
      >
        <div style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 40 }}>
          <div
            style={{
              width: 56,
              height: 56,
              borderRadius: 14,
              background: "linear-gradient(135deg, #6366f1, #a855f7)",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              fontSize: 28,
              fontWeight: 700,
              color: "white",
            }}
          >
            D
          </div>
          <div style={{ fontSize: 40, fontWeight: 700, color: "white" }}>Droply</div>
        </div>
        <div style={{ fontSize: 56, fontWeight: 800, color: "white", lineHeight: 1.15, maxWidth: 900 }}>
          All Crypto Airdrops
        </div>
        <div style={{ fontSize: 28, color: "#a1a8c3", marginTop: 24, maxWidth: 800 }}>
          Snapshots, TGE dates, claims and airdrop events — tracked automatically.
        </div>
      </div>
    ),
    { ...size }
  );
}