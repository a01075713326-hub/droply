# redesign-cryptorank-7.ps1  (run from the project root, after redesign-cryptorank-4.ps1)
# 1) Adds the compact Moni gauge to the project cards used on /airdrops.
# 2) Gives /calendar its own metadata with canonical -> /airdrops (the page and its list stay as they are).
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Read-Text($p)      { [System.IO.File]::ReadAllText($p, $enc) }
function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-redesign7"
  if ((Test-Path -LiteralPath $p) -and -not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$cardsPath  = Join-Path $root "components\ProjectCards.tsx"
$gaugePath  = Join-Path $root "components\MoniGauge.tsx"
$calDir     = Join-Path $root "app\calendar"
$calLayout  = Join-Path $calDir "layout.tsx"

if (-not (Test-Path -LiteralPath $cardsPath)) { throw "Не найден $cardsPath. Запускайте скрипт из корня проекта." }
if (-not (Test-Path -LiteralPath $gaugePath)) { throw "Не найден $gaugePath. Сначала запустите redesign-cryptorank-3.ps1 и redesign-cryptorank-4.ps1." }
if (-not ((Read-Text $gaugePath) -match 'compact')) { throw "MoniGauge.tsx без compact-режима. Сначала запустите redesign-cryptorank-4.ps1." }

# ---------------------------------------------------------------
# 1. ProjectCards.tsx: gauge in the card footer
# ---------------------------------------------------------------
$cards = Read-Text $cardsPath
if ($cards -match 'MoniGauge') {
  Write-Host "ProjectCards.tsx: спидометр уже подключён, пропускаю"
} else {
  $importAnchor = 'import DeadlineBadge from "@/components/DeadlineBadge";'
  $openAnchor   = '<span className="card-open">'

  if (-not $cards.Contains($importAnchor)) { throw "ProjectCards.tsx: не нашёл импорт DeadlineBadge." }
  if (-not $cards.Contains($openAnchor))   { throw "ProjectCards.tsx: не нашёл блок card-open." }

  $gaugeJsx = '{p.twitterScore != null ? <MoniGauge score={Number(p.twitterScore)} compact /> : null}'

  Backup $cardsPath
  $cards = $cards.Replace($importAnchor, $importAnchor + "`nimport MoniGauge from `"@/components/MoniGauge`";")
  $cards = $cards.Replace($openAnchor, $gaugeJsx + "`n`n              " + $openAnchor)
  Write-Text $cardsPath $cards
  Write-Host "ProjectCards.tsx: мини-спидометр Moni добавлен в карточки"
}

# ---------------------------------------------------------------
# 2. app\calendar\layout.tsx: metadata + canonical -> /airdrops
# ---------------------------------------------------------------
$layoutTsx = @'
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Airdrop Calendar",
  description: "Snapshots, TGE dates, claims and airdrop events in one calendar.",
  alternates: { canonical: "/airdrops" },
};

export default function CalendarLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}
'@

if (-not (Test-Path -LiteralPath $calDir)) {
  Write-Host "app\calendar: папки нет, пропускаю canonical"
} elseif (Test-Path -LiteralPath $calLayout) {
  Write-Host "app\calendar\layout.tsx: уже существует, пропускаю (проверьте canonical вручную)"
} else {
  Write-Text $calLayout $layoutTsx
  Write-Host "app\calendar\layout.tsx: создан, canonical указывает на /airdrops"
}

Write-Host ""
Write-Host "Готово. Резервные копии: *.bak-redesign7"
Write-Host "Дальше: npm run dev, откройте /airdrops - у проектов с Moni score в карточке появится спидометр."
