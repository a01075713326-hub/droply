# redesign-cryptorank-3.ps1  (run from the project root, after redesign-cryptorank-2.ps1)
# Replaces the Moni score badge with a speedometer-style gauge (red -> green).
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Read-Text($p)      { [System.IO.File]::ReadAllText($p, $enc) }
function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-redesign3"
  if ((Test-Path -LiteralPath $p) -and -not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$detPath   = Join-Path $root "components\CryptoRankDetails.tsx"
$gaugePath = Join-Path $root "components\MoniGauge.tsx"

if (-not (Test-Path -LiteralPath $detPath)) {
  throw "Не найден $detPath. Сначала запустите redesign-cryptorank-2.ps1 из корня проекта."
}

# ---------------------------------------------------------------
# 1. components/MoniGauge.tsx
# ---------------------------------------------------------------
$gauge = @'
// Speedometer-style Moni score: a half-circle split into colored zones
// (red -> orange -> yellow -> lime -> green) with a needle.

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

export default function MoniGauge({ score }: { score: number }) {
  if (!Number.isFinite(score)) return null;

  const pct = Math.min(Math.max(score / MONI_MAX, 0), 1);
  const step = 180 / SEGMENTS.length;
  const gap = 3;
  const last = SEGMENTS.length - 1;
  const color = SEGMENTS[Math.min(last, Math.floor(pct * SEGMENTS.length))];
  const tip = point(180 - pct * 180, R - 14);
  const text = score.toLocaleString("en-US");

  return (
    <div className="crx-gauge" title={"Moni score: " + text}>
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
            <path key={i} d={arcPath(from, to)} fill="none" stroke={c} strokeWidth={10} />
          );
        })}
        <line
          x1={CX}
          y1={CY}
          x2={tip.x.toFixed(2)}
          y2={tip.y.toFixed(2)}
          stroke="currentColor"
          strokeWidth={3}
          strokeLinecap="round"
        />
        <circle cx={CX} cy={CY} r={5} fill="currentColor" />
      </svg>
      <span className="crx-gauge__text">
        <span className="crx-gauge__label">Moni score</span>
        <strong className="crx-gauge__value" style={{ color }}>
          {text}
        </strong>
      </span>
    </div>
  );
}
'@

if (Test-Path -LiteralPath $gaugePath) {
  Write-Host "MoniGauge.tsx: уже существует, пропускаю"
} else {
  Write-Text $gaugePath $gauge
  Write-Host "MoniGauge.tsx: создан"
}

# ---------------------------------------------------------------
# 2. CryptoRankDetails.tsx: use the gauge instead of the old badge
# ---------------------------------------------------------------
$det = Read-Text $detPath
if ($det -match 'MoniGauge') {
  Write-Host "CryptoRankDetails.tsx: спидометр уже подключён, пропускаю"
} else {
  $rx = '(?s)<div className="crx-moni" title="Moni score">.*?</strong>\s*</span>\s*</div>'
  if (-not [regex]::IsMatch($det, $rx)) { throw "CryptoRankDetails.tsx: не нашёл старый Moni-бейдж. Пришлите файл, подгоню." }

  $importAnchor = 'import type { Project } from "@/data/projects";'
  if (-not $det.Contains($importAnchor)) { throw "CryptoRankDetails.tsx: не нашёл строку импорта Project." }

  Backup $detPath
  $det = [regex]::Replace($det, $rx, '<MoniGauge score={Number(p.twitterScore)} />')
  $det = $det.Replace($importAnchor, $importAnchor + "`nimport MoniGauge from `"@/components/MoniGauge`";")
  $det = [regex]::Replace($det, '\r?\n\s*Gauge,', '')
  Write-Text $detPath $det
  Write-Host "CryptoRankDetails.tsx: Moni-бейдж заменён спидометром"
}

# ---------------------------------------------------------------
# 3. CSS
# ---------------------------------------------------------------
$cssBlock = @'

/* --- CryptoRank redesign 3: Moni speedometer --- */
.crx-gauge {
  display: inline-flex;
  align-items: center;
  gap: 14px;
  padding: 8px 22px 8px 14px;
  border-radius: 16px;
  border: 1px solid var(--crx-border);
  background: var(--crx-surface);
}
.crx-gauge__svg {
  width: 100px;
  height: auto;
  flex: 0 0 auto;
  color: var(--crx-text, #e5e7eb);
}
.crx-gauge__text { display: grid; line-height: 1.15; }
.crx-gauge__label {
  font-size: 11px;
  color: var(--crx-muted);
  text-transform: uppercase;
  letter-spacing: 0.06em;
}
.crx-gauge__value { font-size: 26px; }
'@

$cssFile = Get-ChildItem -Path $root -Recurse -Filter *.css -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(node_modules|\.next)\\' } |
  Where-Object { Select-String -Path $_.FullName -Pattern 'crx-xbadge' -Quiet } |
  Select-Object -First 1

if (-not $cssFile) { throw "CSS: не нашёл файл со стилями crx-*. Сначала запустите redesign-cryptorank-2.ps1." }

$css = Read-Text $cssFile.FullName
if ($css -match 'crx-gauge__svg') {
  Write-Host "CSS: стили спидометра уже добавлены, пропускаю"
} else {
  Backup $cssFile.FullName
  Write-Text $cssFile.FullName ($css.TrimEnd() + "`n" + $cssBlock)
  Write-Host "CSS: стили добавлены в $($cssFile.FullName)"
}

Write-Host ""
Write-Host "Готово. Резервные копии: *.bak-redesign3"
Write-Host "Дальше: npm run dev (sync повторять не нужно)"
