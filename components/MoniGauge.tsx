// Speedometer-style Moni score: a half-circle split into colored zones
// (red -> orange -> yellow -> lime -> green) with a needle.
// `compact` renders a small pill (mini gauge + number) for list rows.

// Top of the scale. If CryptoRank's gauge uses a different range, change this one number.
const MONI_MAX = 5000;

const SEGMENTS = ["#ef4444", "#f97316", "#eab308", "#84cc16", "#22c55e"];

const CX = 60;
const CY = 60;
const R = 50;

function point(angleDeg: number, radius: number) {
  const a = (angleDeg * Math.PI) / 180;
  return { x: CX + radius * Math.cos(a), y: CY - radius * Math.sin(a) };
}

function arcPath(fromDeg: number, toDeg: number) {
  const s = point(fromDeg, R);
  const e = point(toDeg, R);
  return (
    "M " + s.x.toFixed(2) + " " + s.y.toFixed(2) +
    " A " + R + " " + R + " 0 0 1 " + e.x.toFixed(2) + " " + e.y.toFixed(2)
  );
}

export default function MoniGauge({
  score,
  compact = false,
}: {
  score: number;
  compact?: boolean;
}) {
  if (!Number.isFinite(score)) return null;

  const pct = Math.min(Math.max(score / MONI_MAX, 0), 1);
  const step = 180 / SEGMENTS.length;
  const gap = 3;
  const last = SEGMENTS.length - 1;
  const color = SEGMENTS[Math.min(last, Math.floor(pct * SEGMENTS.length))];
  const tip = point(180 - pct * 180, R - 14);
  const text = score.toLocaleString("en-US");

  const arcWidth = compact ? 14 : 10;
  const needleWidth = compact ? 7 : 3;
  const hubRadius = compact ? 7 : 5;

  return (
    <div
      className={"crx-gauge" + (compact ? " crx-gauge--compact" : "")}
      title={"Moni score: " + text}
    >
      <svg
        className="crx-gauge__svg"
        viewBox="0 0 120 68"
        role="img"
        aria-label={"Moni score " + text}
      >
        {SEGMENTS.map((c, i) => {
          const from = 180 - i * step - (i === 0 ? 0 : gap / 2);
          const to = 180 - (i + 1) * step + (i === last ? 0 : gap / 2);
          return (
            <path key={i} d={arcPath(from, to)} fill="none" stroke={c} strokeWidth={arcWidth} />
          );
        })}
        <line
          x1={CX}
          y1={CY}
          x2={tip.x.toFixed(2)}
          y2={tip.y.toFixed(2)}
          stroke="currentColor"
          strokeWidth={needleWidth}
          strokeLinecap="round"
        />
        <circle cx={CX} cy={CY} r={hubRadius} fill="currentColor" />
      </svg>
      {compact ? (
        <strong className="crx-gauge__value" style={{ color }}>
          {text}
        </strong>
      ) : (
        <span className="crx-gauge__text">
          <span className="crx-gauge__label">Moni score</span>
          <strong className="crx-gauge__value" style={{ color }}>
            {text}
          </strong>
        </span>
      )}
    </div>
  );
}