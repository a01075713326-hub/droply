# redesign-cryptorank-4.ps1  (run from the project root, after redesign-cryptorank-3.ps1)
# Shows a compact Moni speedometer in the "All Airdrops" list (app\calendar\page.tsx)
# for every project that has a Moni score.
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Read-Text($p)      { [System.IO.File]::ReadAllText($p, $enc) }
function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-redesign4"
  if ((Test-Path -LiteralPath $p) -and -not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$gaugePath = Join-Path $root "components\MoniGauge.tsx"
$pagePath  = Join-Path $root "app\calendar\page.tsx"

if (-not (Test-Path -LiteralPath $pagePath)) { throw "Не найден $pagePath. Запускайте скрипт из корня проекта." }

# ---------------------------------------------------------------
# 1. components/MoniGauge.tsx: add compact mode
# ---------------------------------------------------------------
$gauge = @'
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
'@

$needsGauge = $true
if (Test-Path -LiteralPath $gaugePath) {
  if ((Read-Text $gaugePath) -match 'compact') { $needsGauge = $false }
}
if ($needsGauge) {
  Backup $gaugePath
  Write-Text $gaugePath $gauge
  Write-Host "MoniGauge.tsx: добавлен компактный режим"
} else {
  Write-Host "MoniGauge.tsx: компактный режим уже есть, пропускаю"
}

# ---------------------------------------------------------------
# 2. app/calendar/page.tsx: show the gauge in each row
# ---------------------------------------------------------------
$page = Read-Text $pagePath
if ($page -match 'MoniGauge') {
  Write-Host "calendar/page.tsx: спидометр уже подключён, пропускаю"
} else {
  $importAnchor = 'import DeadlineBadge from "@/components/DeadlineBadge";'
  $favAnchor    = '<span onClick={(e) => e.stopPropagation()}><FavoriteButton slug={p.slug} /></span>'

  if (-not $page.Contains($importAnchor)) { throw "calendar/page.tsx: не нашёл импорт DeadlineBadge." }
  if (-not $page.Contains($favAnchor))    { throw "calendar/page.tsx: не нашёл кнопку избранного в строке." }

  $slot = '<span className="crx-gauge-slot">{p.twitterScore != null ? <MoniGauge score={Number(p.twitterScore)} compact /> : null}</span>'

  Backup $pagePath
  $page = $page.Replace($importAnchor, $importAnchor + "`nimport MoniGauge from `"@/components/MoniGauge`";")
  $page = $page.Replace($favAnchor, $slot + "`n              " + $favAnchor)
  Write-Text $pagePath $page
  Write-Host "calendar/page.tsx: мини-спидометр добавлен в строки списка"
}

# ---------------------------------------------------------------
# 3. CSS
# ---------------------------------------------------------------
$cssBlock = @'

/* --- CryptoRank redesign 4: compact Moni gauge in list rows --- */
.crx-gauge-slot {
  display: flex;
  justify-content: center;
  width: 96px;
  flex-shrink: 0;
}
@media (max-width: 720px) {
  .crx-gauge-slot { display: none; }
}
.crx-gauge--compact {
  gap: 6px;
  padding: 3px 10px 3px 6px;
  border-radius: 999px;
  border: 1px solid var(--crx-border, rgba(255, 255, 255, 0.12));
  background: var(--crx-surface, rgba(255, 255, 255, 0.04));
}
.crx-gauge--compact .crx-gauge__svg { width: 34px; }
.crx-gauge--compact .crx-gauge__value { font-size: 13px; }
'@

$cssFile = Get-ChildItem -Path $root -Recurse -Filter *.css -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(node_modules|\.next)\\' } |
  Where-Object { Select-String -Path $_.FullName -Pattern 'crx-xbadge' -Quiet } |
  Select-Object -First 1

if (-not $cssFile) { throw "CSS: не нашёл файл со стилями crx-*. Сначала запустите redesign-cryptorank-2.ps1 и redesign-cryptorank-3.ps1." }

$css = Read-Text $cssFile.FullName
if ($css -match 'crx-gauge-slot') {
  Write-Host "CSS: стили уже добавлены, пропускаю"
} else {
  Backup $cssFile.FullName
  Write-Text $cssFile.FullName ($css.TrimEnd() + "`n" + $cssBlock)
  Write-Host "CSS: стили добавлены в $($cssFile.FullName)"
}

Write-Host ""
Write-Host "Готово. Резервные копии: *.bak-redesign4"
Write-Host "Дальше: npm run dev"
