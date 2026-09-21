# redesign-cryptorank-5.ps1  (run from the project root)
# SEO patch for app\project\[slug]\page.tsx:
#  - meta description built from real project data (not a copy of the source text)
#  - BreadcrumbList JSON-LD
#  - visible FAQ block generated only from fields the project actually has
#  - meaningful alt text for the logo
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Read-Text($p)      { [System.IO.File]::ReadAllText($p, $enc) }
function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-redesign5"
  if ((Test-Path -LiteralPath $p) -and -not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$pagePath = Join-Path $root "app\project\[slug]\page.tsx"
if (-not (Test-Path -LiteralPath $pagePath)) { throw "Не найден $pagePath. Запускайте скрипт из корня проекта." }

# ---------------------------------------------------------------
# 1. app\project\[slug]\page.tsx
# ---------------------------------------------------------------
$helpers = @'
type FaqItem = { q: string; a: string };

function fmtLongDate(value?: string): string {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleDateString("en-US", {
    month: "long",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  });
}

// Meta description assembled from the project's own facts.
function buildDescription(p: any): string {
  const facts: string[] = [];
  if (p.status) facts.push("Status: " + p.status);
  if (p.chain) facts.push("Chain: " + p.chain);
  if (p.costToFarm) facts.push("Cost to farm: " + p.costToFarm);
  if (p.timeToFarm) facts.push("Time: " + p.timeToFarm);

  const head = p.name + " airdrop guide \u2014 how to participate, tasks and requirements.";
  const text = facts.length ? head + " " + facts.join(" \u00b7 ") : head;
  return text.length > 158 ? text.slice(0, 155).trimEnd() + "\u2026" : text;
}

// FAQ answers use only data the project really has; a question with no data is skipped.
function buildFaq(p: any): FaqItem[] {
  const out: FaqItem[] = [];
  const name = String(p.name);
  const tasks = Array.isArray(p.tasks) ? p.tasks : [];

  if (p.status) {
    let a = name + " is currently listed as " + p.status + ".";
    if (p.isLive) a += " The campaign is live right now.";
    out.push({ q: "Is the " + name + " airdrop confirmed?", a });
  }

  const dist = fmtLongDate(p.distributeDate);
  const ends = tasks.map((t: any) => t?.endDate).filter(Boolean).sort();
  const lastEnd = fmtLongDate(ends[ends.length - 1]);

  if (dist) {
    out.push({
      q: "When is the " + name + " airdrop distribution?",
      a: "Distribution is listed for " + dist + ".",
    });
  } else if (lastEnd) {
    out.push({
      q: "When is the deadline for the " + name + " airdrop?",
      a: "The latest task deadline listed is " + lastEnd + ". No distribution date is listed yet.",
    });
  }

  const cost = p.costToFarm ? String(p.costToFarm) : "";
  const time = p.timeToFarm ? String(p.timeToFarm) : "";
  if (cost || time) {
    const parts: string[] = [];
    if (cost) parts.push("Estimated cost to farm: " + cost + ".");
    if (time) parts.push("Estimated time: " + time + ".");
    out.push({ q: "How much does it cost to farm the " + name + " airdrop?", a: parts.join(" ") });
  }

  if (p.chain) {
    out.push({
      q: "Which blockchain does " + name + " use?",
      a: name + " is listed on " + p.chain + ".",
    });
  }

  const steps = Array.isArray(p.actions) && p.actions.length ? p.actions.length : tasks.length;
  if (steps) {
    out.push({
      q: "How do I participate in the " + name + " airdrop?",
      a: "The guide above lists " + steps + (steps === 1 ? " step" : " steps") + " to follow.",
    });
  }

  return out;
}

'@

$faqBlock = @'
{faqItems.length ? (
        <section className="article-card faq-card" aria-labelledby="faq-title">
          <h2 id="faq-title" className="faq-card__title">
            {p.name} airdrop: frequently asked questions
          </h2>
          <div className="faq-list">
            {faqItems.map((f) => (
              <details key={f.q} className="faq-item">
                <summary>{f.q}</summary>
                <p>{f.a}</p>
              </details>
            ))}
          </div>
        </section>
      ) : null}

      
'@

$breadcrumbBlock = @'
<script
        type="application/ld+json"
        dangerouslySetInnerHTML={{
          __html: JSON.stringify({
            "@context": "https://schema.org",
            "@type": "BreadcrumbList",
            itemListElement: [
              { "@type": "ListItem", position: 1, name: "Home", item: "https://droply.digital/" },
              { "@type": "ListItem", position: 2, name: "Airdrops", item: "https://droply.digital/airdrops" },
              { "@type": "ListItem", position: 3, name: p.name, item: `https://droply.digital/project/${p.slug}` },
            ],
          }).replace(/</g, "\\u003c"),
        }}
      />
      
'@

$page = Read-Text $pagePath

if ($page -match 'buildFaq') {
  Write-Host "page.tsx: SEO-патч уже применён, пропускаю"
} else {
  $metaAnchor   = 'export async function generateMetadata('
  $descAnchor   = 'const description = p.description;'
  $backAnchor   = '<Link href="/airdrops" className="back-link">&larr; All drops</Link>'
  $logoAnchor   = '{p.logo ? <img src={p.logo} alt="" /> : initials(p.name)}'
  $jsonLdAnchor = 'const jsonLd = p.actions && p.actions.length ? {'
  $verifAnchor  = '{/* Verification now sits after the guide'

  foreach ($a in @($metaAnchor, $descAnchor, $backAnchor, $logoAnchor, $jsonLdAnchor, $verifAnchor)) {
    if (-not $page.Contains($a)) { throw "page.tsx: не нашёл место для вставки: $a. Пришлите файл, подгоню." }
  }

  Backup $pagePath

  $page = $page.Replace($metaAnchor, $helpers + $metaAnchor)
  $page = $page.Replace($descAnchor, 'const description = buildDescription(p);')
  $page = $page.Replace($jsonLdAnchor, "const faqItems = buildFaq(p);`n`n  " + $jsonLdAnchor)
  $page = $page.Replace($backAnchor, $breadcrumbBlock + $backAnchor)
  $page = $page.Replace($logoAnchor, '{p.logo ? <img src={p.logo} alt={`${p.name} logo`} /> : initials(p.name)}')
  $page = $page.Replace($verifAnchor, $faqBlock + $verifAnchor)

  Write-Text $pagePath $page
  Write-Host "page.tsx: описание, BreadcrumbList, FAQ и alt для логотипа добавлены"
}

# ---------------------------------------------------------------
# 2. CSS for the FAQ block
# ---------------------------------------------------------------
$cssBlock = @'

/* --- CryptoRank redesign 5: FAQ block on the project page --- */
.faq-card { display: grid; gap: 12px; margin-top: 20px; }
.faq-card__title { margin: 0; font-size: 20px; }
.faq-list { display: grid; gap: 8px; }
.faq-item {
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.03);
}
.faq-item summary {
  cursor: pointer;
  padding: 12px 14px;
  font-weight: 600;
  list-style: none;
}
.faq-item summary::-webkit-details-marker { display: none; }
.faq-item summary::after { content: "+"; float: right; opacity: 0.6; }
.faq-item[open] summary::after { content: "\2212"; }
.faq-item p { margin: 0; padding: 0 14px 14px; opacity: 0.8; line-height: 1.6; }
'@

$cssFile = Get-ChildItem -Path $root -Recurse -Filter *.css -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(node_modules|\.next)\\' } |
  Where-Object { Select-String -Path $_.FullName -Pattern 'crx-xbadge' -Quiet } |
  Select-Object -First 1

if (-not $cssFile) { throw "CSS: не нашёл файл со стилями crx-*. Сначала запустите redesign-cryptorank-2.ps1." }

$css = Read-Text $cssFile.FullName
if ($css -match 'faq-card__title') {
  Write-Host "CSS: стили FAQ уже добавлены, пропускаю"
} else {
  Backup $cssFile.FullName
  Write-Text $cssFile.FullName ($css.TrimEnd() + "`n" + $cssBlock)
  Write-Host "CSS: стили добавлены в $($cssFile.FullName)"
}

Write-Host ""
Write-Host "Готово. Резервные копии: *.bak-redesign5"
Write-Host "Дальше: npm run dev, откройте любую страницу проекта."
