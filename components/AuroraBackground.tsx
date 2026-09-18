"use client";

import { useEffect, useRef } from "react";

const BARS = 26;

const TOKENS = [
  { top: 6, left: 8, size: 70, duration: 26, delay: 0, rotate: 15, chain: "base" },
  { top: 14, left: 55, size: 50, duration: 22, delay: 3, rotate: 200, chain: "solana" },
  { top: 4, left: 85, size: 85, duration: 30, delay: 1, rotate: 340, chain: "ethereum" },
  { top: 18, left: 92, size: 55, duration: 24, delay: 5, rotate: 95, chain: "arbitrum" },
  { top: 24, left: 60, size: 65, duration: 28, delay: 2, rotate: 260, chain: "aptos" },
  { top: 10, left: 40, size: 45, duration: 20, delay: 4, rotate: 60, chain: "polygon" },
  { top: 20, left: 70, size: 40, duration: 18, delay: 6, rotate: 310, chain: "base" },
  { top: 26, left: 15, size: 60, duration: 25, delay: 1.5, rotate: 130, chain: "ethereum" },
  { top: 34, left: 20, size: 55, duration: 23, delay: 2.5, rotate: 80, chain: "solana" },
  { top: 40, left: 75, size: 70, duration: 27, delay: 0.5, rotate: 220, chain: "arbitrum" },
  { top: 46, left: 45, size: 45, duration: 21, delay: 4.5, rotate: 10, chain: "aptos" },
  { top: 52, left: 88, size: 60, duration: 29, delay: 3.5, rotate: 300, chain: "polygon" },
  { top: 58, left: 10, size: 50, duration: 24, delay: 1, rotate: 150, chain: "base" },
  { top: 64, left: 65, size: 65, duration: 26, delay: 5.5, rotate: 45, chain: "ethereum" },
  { top: 70, left: 30, size: 55, duration: 22, delay: 2, rotate: 190, chain: "solana" },
  { top: 76, left: 82, size: 70, duration: 28, delay: 0, rotate: 270, chain: "arbitrum" },
  { top: 82, left: 50, size: 45, duration: 20, delay: 3, rotate: 120, chain: "aptos" },
  { top: 88, left: 18, size: 60, duration: 25, delay: 4, rotate: 55, chain: "polygon" },
  { top: 94, left: 68, size: 50, duration: 23, delay: 1.5, rotate: 240, chain: "base" },
  { top: 98, left: 38, size: 65, duration: 27, delay: 5, rotate: 330, chain: "ethereum" },
];

export default function AuroraBackground() {
  const containerRef = useRef<HTMLDivElement>(null);
  const tokensRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const reduceMotion = typeof window !== "undefined" && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduceMotion) return;

    const bars = Array.from(container.children) as HTMLDivElement[];
    let raf = 0;
    let frame = 0;
    let t = 0;
    let mouseX = typeof window !== "undefined" ? window.innerWidth / 2 : 0;

    const onMove = (e: MouseEvent) => {
      mouseX = e.clientX;
    };

    const animate = () => {
      frame++;

      if (frame % 2 === 0) {
        t += 0.3;
        const w = window.innerWidth;

        bars.forEach((bar, i) => {
          const barX = ((i + 0.5) / BARS) * w;
          const dist = Math.abs(barX - mouseX);
          const proximity = Math.max(0, 1 - dist / (w * 0.3));
          const wobble = Math.sin((t + i * 14) * 0.012) * 22;
          const hue = wobble + proximity * 30;
          const bright = 0.22 + Math.sin((t + i * 10) * 0.015) * 0.05 + proximity * 0.28;

          bar.style.filter = `hue-rotate(${hue}deg) brightness(${bright})`;
          bar.style.transform = `scaleY(${1 + proximity * 0.04})`;
        });

        if (tokensRef.current) {
          const scrollY = window.scrollY || window.pageYOffset || 0;
          tokensRef.current.style.transform = `translateY(${-scrollY * 0.18}px)`;
        }
      }

      raf = requestAnimationFrame(animate);
    };

    window.addEventListener("mousemove", onMove);
    raf = requestAnimationFrame(animate);

    return () => {
      window.removeEventListener("mousemove", onMove);
      cancelAnimationFrame(raf);
    };
  }, []);

  return (
    <div className="aurora-wrap" aria-hidden="true">
      <div className="aurora-bg" ref={containerRef}>
        {Array.from({ length: BARS }).map((_, i) => (
          <div key={i} className="aurora-bar" />
        ))}
      </div>
      <div className="floating-tokens" ref={tokensRef} aria-hidden="true">
        {TOKENS.map((t, i) => (
          <div
            key={i}
            className="token-wrap"
            style={{
              left: `${t.left}%`,
              top: `${t.top}%`,
              width: `${t.size}px`,
              height: `${t.size}px`,
              animationDuration: `${t.duration}s`,
              animationDelay: `${t.delay}s`,
            }}
          >
            <img
              src={`https://icons.llamao.fi/icons/chains/rsz_${t.chain}.jpg`}
              alt=""
              className="token-coin-img"
              style={{ transform: `rotate(${t.rotate}deg)` }}
            />
          </div>
        ))}
      </div>
      <div className="aurora-vignette" />
    </div>
  );
}