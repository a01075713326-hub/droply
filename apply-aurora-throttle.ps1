$ErrorActionPreference = "Stop"

$root = $PSScriptRoot
Set-Location $root

Write-Host "Working in: $root"

$path = Join-Path $root "components\AuroraBackground.tsx"
$content = @'
"use client";

import { useEffect, useRef } from "react";

const BARS = 26;

export default function AuroraBackground() {
  const containerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

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

      // Recalculate styles every other frame (~30fps) instead of every
      // frame (~60fps). The wobble is slow enough that this is visually
      // identical, but it halves the main-thread cost of this always-on
      // background loop, which was competing with other UI interactions
      // (e.g. scrolling a long dropdown list) for render time.
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
      <div className="aurora-vignette" />
    </div>
  );
}
'@

[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
Write-Host "Written: $path"

Write-Host ""
Write-Host "Done. Restart the dev server if needed and hard-refresh /airdrops."
