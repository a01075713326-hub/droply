# add-cryptorank-details.ps1  (run from the project root)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Read-Text($p)      { [System.IO.File]::ReadAllText($p, $enc) }
function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-details"
  if (-not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$syncPath  = Join-Path $root "scripts\sync.js"
$typesPath = Join-Path $root "data\projects.ts"
$compPath  = Join-Path $root "components\CryptoRankDetails.tsx"

foreach ($f in @($syncPath, $typesPath, $compPath)) {
  if (-not (Test-Path -LiteralPath $f)) { throw "Не найден файл: $f. Запустите скрипт из корня проекта." }
}

# ---------------------------------------------------------------
# 1. scripts/sync.js
# ---------------------------------------------------------------
$enrichJs = @'
    // ---- get_activity_detail: tasks, links, ecosystems, claim URL, dates ----
    const detailBase =
      "https://api.parse.bot/scraper/3888881d-79db-46c9-8892-13115f4f0ab6/get_activity_detail";

    const previousHistory = await loadCryptoRankHistory();

    const DETAIL_KEYS = [
      "tasks",
      "extraLinks",
      "ecosystems",
      "category",
      "distributeDate",
      "website",
      "x",
      "telegram",
      "discord",
    ];

    const safeUrl = (u) => {
      const s = String(typeof u === "string" ? u : u?.url || "").trim();
      return /^https?:\/\//i.test(s) ? s : "";
    };

    const firstUrl = (arr) => {
      for (const u of Array.isArray(arr) ? arr : []) {
        const s = safeUrl(u);
        if (s) return s;
      }
      return "";
    };

    const fetchDetail = async (key) => {
      for (let attempt = 0; attempt < 2; attempt++) {
        try {
          const res = await fetch(
            `${detailBase}?activity_key=${encodeURIComponent(key)}`,
            {
              headers: {
                Accept: "application/json",
                "X-API-Key": process.env.PARSE_API_KEY,
              },
            }
          );

          if (res.ok) {
            const body = await res.json();
            return body?.data?.activity || body?.data || body?.activity || body;
          }

          console.warn(`CryptoRank detail ${key}: HTTP ${res.status}`);

          if (res.status < 500 && res.status !== 429) return null;
        } catch (error) {
          console.warn(
            `CryptoRank detail ${key}: ${error?.message || "request failed"}`
          );
        }

        await sleep(1000);
      }

      return null;
    };

    // Copies useful fields from the detail response onto the project.
    // description / description_html (third-party HTML) are NOT stored.
    const applyDetail = (p, d) => {
      if (!d || typeof d !== "object") return false;

      const valid =
        d.activity_key || d.project_name || Array.isArray(d.tasks);
      if (!valid) return false;

      const short = cleanText(d.short_description);
      if (short) p.description = short;

      if (d.category) p.category = String(d.category);

      if (Array.isArray(d.ecosystems)) {
        const eco = d.ecosystems.map(String).filter(Boolean);
        if (eco.length) {
          p.ecosystems = eco;
          p.chain =
            eco.length === 1 ? normalizeChain(eco[0]) || eco[0] : "Multiple";
        }
      }

      if (d.distribute_date) {
        p.distributeDate = String(d.distribute_date).slice(0, 10);
      }

      const claim = safeUrl(d.link_to_claim);
      if (claim) p.claimUrl = claim;

      if (!p.costToFarm && Number(d.cost_usd) > 0) {
        p.costToFarm = "$" + d.cost_usd;
      }
      if (!p.timeToFarm && Number(d.time_minutes) > 0) {
        p.timeToFarm = d.time_minutes + " min";
      }

      const links = d.links && typeof d.links === "object" ? d.links : {};
      const website = firstUrl(links.web);
      const twitter = firstUrl(links.twitter);
      const telegram = firstUrl(links.telegram);
      const discord = firstUrl(links.discord);

      if (website) p.website = website;
      if (twitter) p.x = twitter;
      if (telegram) p.telegram = telegram;
      if (discord) p.discord = discord;

      const known = new Set(["web", "twitter", "telegram", "discord"]);
      const extra = [];
      for (const [label, urls] of Object.entries(links)) {
        if (known.has(label)) continue;
        for (const u of Array.isArray(urls) ? urls : []) {
          const s = safeUrl(u);
          if (s) extra.push({ label, url: s });
        }
      }
      if (extra.length) p.extraLinks = extra.slice(0, 12);

      if (Array.isArray(d.tasks)) {
        const tasks = d.tasks
          .map((t) => ({
            id: t?.task_id,
            title: cleanText(t?.title),
            status: t?.status ? String(t.status) : undefined,
            types: Array.isArray(t?.types)
              ? t.types.map(String)
              : t?.type
                ? [String(t.type)]
                : undefined,
            startDate: t?.start_date
              ? String(t.start_date).slice(0, 10)
              : undefined,
            endDate: t?.end_date ? String(t.end_date).slice(0, 10) : undefined,
            isNew: t?.is_new === true ? true : undefined,
            exclusive: t?.exclusive === true ? true : undefined,
          }))
          .filter((t) => t.title);

        if (tasks.length) p.tasks = tasks;
      }

      return true;
    };

    let detailOk = 0;
    let detailCursor = 0;
    let shapeLogged = false;

    const detailWorker = async () => {
      while (true) {
        const i = detailCursor++;
        if (i >= projects.length) return;

        const p = projects[i];
        const key = activities[i]?.key || activities[i]?.activity_key;
        if (!key) continue;

        const d = await fetchDetail(key);

        if (d && applyDetail(p, d)) {
          detailOk++;
        } else {
          if (d && !shapeLogged) {
            shapeLogged = true;
            console.warn(
              "CryptoRank detail: unexpected response, keys: " +
                Object.keys(d).join(", ")
            );
          }

          // Keep what we already had from a previous sync.
          const prev = previousHistory.get(p.slug);
          if (prev) {
            for (const k of DETAIL_KEYS) {
              if (p[k] === undefined && prev[k] !== undefined) p[k] = prev[k];
            }
          }
        }

        await sleep(150);
      }
    };

    await Promise.all(Array.from({ length: 3 }, detailWorker));

    console.log(
      `CryptoRank: ${projects.length} projects, details loaded for ${detailOk}`
    );
'@

$firstSeenJs = @'
async function loadPreviousFirstSeen() {
  const filePath = path.join(__dirname, "..", "data", "projects.generated.ts");
  const map = new Map();

  try {
    const content = await fs.readFile(filePath, "utf8");

    // Projects contain nested objects (investors, tasks), so a simple
    // "{ ... }" regex is not enough. Walk the file, track brace depth
    // (ignoring braces inside strings) and read one top-level object at a time.
    let depth = 0;
    let inStr = false;
    let esc = false;
    let start = -1;

    for (let i = 0; i < content.length; i++) {
      const ch = content[i];

      if (inStr) {
        if (esc) esc = false;
        else if (ch === "\\") esc = true;
        else if (ch === '"') inStr = false;
        continue;
      }

      if (ch === '"') {
        inStr = true;
        continue;
      }

      if (ch === "{") {
        if (depth === 0) start = i;
        depth++;
      } else if (ch === "}") {
        depth--;

        if (depth === 0 && start >= 0) {
          const block = content.slice(start, i + 1);
          const slug = block.match(/"slug":\s*"([^"]+)"/)?.[1];
          const seen = block.match(/"firstSeenAt":\s*"([^"]+)"/)?.[1];

          if (slug && seen) map.set(slug, seen);
          start = -1;
        }
      }
    }
  } catch {
    // No previous file yet (first run) - everything is new.
  }

  return map;
}

'@

$sync = Read-Text $syncPath
$syncChanged = $false

if ($sync -match 'get_activity_detail') {
  Write-Host "sync.js: детали уже подключены, пропускаю"
} else {
  $pattern = '(?s)console\.log\(\s*`CryptoRank: enrichment disabled[^`]*`\s*\);'
  $m = [regex]::Match($sync, $pattern)
  if (-not $m.Success) {
    throw "sync.js: не нашёл лог 'enrichment disabled'. Пришлите строки 826-850 файла scripts\sync.js."
  }
  $sync = $sync.Substring(0, $m.Index) + $enrichJs.TrimEnd() + $sync.Substring($m.Index + $m.Length)
  $syncChanged = $true
  Write-Host "sync.js: вызов get_activity_detail добавлен"
}

if ($sync -notmatch 'depth === 0') {
  $pat2 = '(?s)async function loadPreviousFirstSeen\(\) \{.*?\r?\n\}\r?\n(?=\s*async function loadCryptoRankHistory)'
  $m2 = [regex]::Match($sync, $pat2)
  if ($m2.Success) {
    $sync = $sync.Substring(0, $m2.Index) + $firstSeenJs + $sync.Substring($m2.Index + $m2.Length)
    $syncChanged = $true
    Write-Host "sync.js: loadPreviousFirstSeen исправлена (firstSeenAt больше не теряется)"
  } else {
    Write-Warning "sync.js: не нашёл loadPreviousFirstSeen, эту часть пропустил"
  }
}

if ($syncChanged) {
  Backup $syncPath
  Write-Text $syncPath $sync
}

# ---------------------------------------------------------------
# 2. data/projects.ts (types)
# ---------------------------------------------------------------
$taskType = @'
export type ProjectTask = {
  id?: number;
  title: string;
  status?: string;
  types?: string[];
  startDate?: string;
  endDate?: string;
  isNew?: boolean;
  exclusive?: boolean;
};

'@

$newFields = @'

  ecosystems?: string[];
  category?: string;
  distributeDate?: string;
  tasks?: ProjectTask[];
  extraLinks?: { label: string; url: string }[];
'@

$types = Read-Text $typesPath
if ($types -match 'ProjectTask') {
  Write-Host "projects.ts: типы уже добавлены, пропускаю"
} else {
  $typeMarker  = 'export type Project = {'
  $fieldMarker = '  twitterFollowers?: number;'
  $a = $types.IndexOf($typeMarker)
  $b = $types.IndexOf($fieldMarker)
  if ($a -lt 0 -or $b -lt 0) { throw "projects.ts: не нашёл тип Project или поле twitterFollowers." }

  Backup $typesPath
  $types = $types.Insert($b + $fieldMarker.Length, $newFields.TrimEnd())
  $types = $types.Insert($a, $taskType)
  Write-Text $typesPath $types
  Write-Host "projects.ts: типы ProjectTask и новые поля добавлены"
}

# ---------------------------------------------------------------
# 3. components/CryptoRankDetails.tsx (full replacement)
# ---------------------------------------------------------------
$component = @'
import { ArrowUpRight } from "lucide-react";
import type { Project } from "@/data/projects";

type Investor = {
  name?: string;
  tier?: number | null;
  category?: string;
  is_lead?: boolean;
};

type Stat = { label: string; value: string };

function compactUsd(value?: string): string | null {
  if (!value) return null;
  const n = Number(String(value).replace(/[^0-9.]/g, ""));
  if (!Number.isFinite(n) || n <= 0) return value;
  const s = new Intl.NumberFormat("en-US", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(n);
  return "$" + s;
}

function fmtDate(value?: string): string {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return value;
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  });
}

function taskDates(start?: string, end?: string): string {
  if (start && end) return fmtDate(start) + " \u2013 " + fmtDate(end);
  if (start) return "from " + fmtDate(start);
  if (end) return "until " + fmtDate(end);
  return "";
}

function niceLabel(value?: string): string {
  if (!value) return "";
  const t = value.replace(/[_-]+/g, " ").toLowerCase();
  return t.charAt(0).toUpperCase() + t.slice(1);
}

export default function CryptoRankDetails({ project: p }: { project: Project }) {
  const investors = (Array.isArray(p.topInvestors) ? p.topInvestors : []) as Investor[];
  const tasks = Array.isArray(p.tasks) ? p.tasks : [];
  const ecosystems = Array.isArray(p.ecosystems) ? p.ecosystems : [];
  const extraLinks = Array.isArray(p.extraLinks) ? p.extraLinks : [];

  const stats: Stat[] = [];
  const add = (label: string, value: unknown) => {
    if (value === undefined || value === null || value === "") return;
    stats.push({ label, value: String(value) });
  };

  add("Category", p.category);
  add("Distribution", fmtDate(p.distributeDate));
  add("Activity points", p.activityPoints);
  add("Rating", p.rating);
  add("Cost to farm", p.costToFarm);
  add("Time to farm", p.timeToFarm);
  add("Reward type", p.rewardType);
  add("Total funding", compactUsd(p.funding));
  add("Investors", p.investorCount);
  add(
    "Twitter followers",
    p.twitterFollowers != null ? p.twitterFollowers.toLocaleString("en-US") : null
  );
  add("Moni score", p.twitterScore);

  return (
    <section className="cr-details" aria-label="CryptoRank data">
      <div className="cr-details__head">
        <h2 className="cr-details__title">CryptoRank data</h2>
        {p.sourceUrl ? (
          <a className="cr-details__link" href={p.sourceUrl} target="_blank" rel="noreferrer">
            Open on CryptoRank <ArrowUpRight size={14} />
          </a>
        ) : null}
      </div>

      {stats.length ? (
        <div className="cr-stats">
          {stats.map((s) => (
            <div key={s.label} className="cr-stat">
              <span className="cr-stat__label">{s.label}</span>
              <strong className="cr-stat__value">{s.value}</strong>
            </div>
          ))}
        </div>
      ) : null}

      <div className="cr-flags">
        {p.noActiveTask != null ? (
          <span className={"cr-flag " + (p.noActiveTask ? "cr-flag--warn" : "cr-flag--ok")}>
            {p.noActiveTask ? "No active task" : "Task active"}
          </span>
        ) : null}
        {p.isAuthProtected != null ? (
          <span className="cr-flag">Auth protected: {p.isAuthProtected ? "yes" : "no"}</span>
        ) : null}
      </div>

      {ecosystems.length ? (
        <div className="cr-block">
          <h3 className="cr-block__title">Ecosystems</h3>
          <div className="cr-chips">
            {ecosystems.map((e) => (
              <span key={e} className="type-pill">{e}</span>
            ))}
          </div>
        </div>
      ) : null}

      {p.activityTypes && p.activityTypes.length ? (
        <div className="cr-block">
          <h3 className="cr-block__title">Activity types</h3>
          <div className="cr-chips">
            {p.activityTypes.map((t) => (
              <span key={t} className="type-pill">{t}</span>
            ))}
          </div>
        </div>
      ) : null}

      {tasks.length ? (
        <div className="cr-block">
          <h3 className="cr-block__title">Tasks ({tasks.length})</h3>
          <ul className="cr-tasks">
            {tasks.map((t, i) => {
              const dates = taskDates(t.startDate, t.endDate);
              return (
                <li key={String(t.id ?? "task") + "-" + i} className="cr-task">
                  <div className="cr-task__top">
                    <span className="cr-task__title">{t.title}</span>
                    <span className="cr-task__badges">
                      {t.isNew ? <span className="cr-badge">New</span> : null}
                      {t.exclusive ? <span className="cr-badge cr-badge--lead">Exclusive</span> : null}
                      {t.status ? <span className="cr-badge">{niceLabel(t.status)}</span> : null}
                    </span>
                  </div>
                  {dates || (t.types && t.types.length) ? (
                    <div className="cr-task__meta">
                      {dates ? <span>{dates}</span> : null}
                      {t.types && t.types.length
                        ? t.types.map((ty) => (
                            <span key={ty} className="type-pill">{ty}</span>
                          ))
                        : null}
                    </div>
                  ) : null}
                </li>
              );
            })}
          </ul>
          {p.sourceUrl ? (
            <p className="cr-note">
              Full task instructions:{" "}
              <a href={p.sourceUrl} target="_blank" rel="noreferrer">
                open on CryptoRank
              </a>
            </p>
          ) : null}
        </div>
      ) : null}

      {extraLinks.length ? (
        <div className="cr-block">
          <h3 className="cr-block__title">More links</h3>
          <div className="cr-chips">
            {extraLinks.map((l, i) => (
              <a
                key={l.url + i}
                className="type-pill"
                href={l.url}
                target="_blank"
                rel="noreferrer noopener"
              >
                {niceLabel(l.label)}
              </a>
            ))}
          </div>
        </div>
      ) : null}

      {investors.length ? (
        <div className="cr-block">
          <h3 className="cr-block__title">
            Top investors
            {p.investorCount ? " (" + investors.length + " of " + p.investorCount + ")" : ""}
          </h3>
          <ul className="cr-investors">
            {investors.map((inv, i) => (
              <li key={(inv.name ?? "investor") + i} className="cr-investor">
                <span className="cr-investor__name">{inv.name}</span>
                <span className="cr-investor__meta">
                  {inv.category ? <span>{inv.category}</span> : null}
                  {inv.tier != null ? <span className="cr-badge">Tier {inv.tier}</span> : null}
                  {inv.is_lead ? <span className="cr-badge cr-badge--lead">Lead</span> : null}
                </span>
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}
'@

Backup $compPath
Write-Text $compPath $component
Write-Host "CryptoRankDetails.tsx: обновлён (задачи, экосистемы, доп. ссылки)"

# ---------------------------------------------------------------
# 4. CSS for the task list
# ---------------------------------------------------------------
$cssBlock = @'

/* --- CryptoRank tasks (add-cryptorank-details) --- */
.cr-tasks { list-style: none; margin: 0; padding: 0; display: grid; gap: 8px; }
.cr-task { border: 1px solid rgba(128, 128, 128, 0.25); border-radius: 10px; padding: 10px 12px; display: grid; gap: 6px; }
.cr-task__top { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; flex-wrap: wrap; }
.cr-task__title { font-weight: 600; }
.cr-task__badges { display: inline-flex; gap: 6px; flex-wrap: wrap; }
.cr-task__meta { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; font-size: 13px; opacity: 0.85; }
.cr-note { font-size: 13px; opacity: 0.7; margin: 8px 0 0; }
'@

$cssFile = Get-ChildItem -Path $root -Recurse -Filter *.css -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(node_modules|\.next)\\' } |
  Where-Object { Select-String -Path $_.FullName -Pattern 'cr-stats' -Quiet } |
  Select-Object -First 1

if (-not $cssFile) {
  $fallback = Join-Path $root "app\globals.css"
  if (Test-Path -LiteralPath $fallback) { $cssFile = Get-Item -LiteralPath $fallback }
}

if ($cssFile) {
  $css = Read-Text $cssFile.FullName
  if ($css -match 'cr-task__title') {
    Write-Host "CSS: стили задач уже есть, пропускаю"
  } else {
    Backup $cssFile.FullName
    Write-Text $cssFile.FullName ($css.TrimEnd() + "`n" + $cssBlock)
    Write-Host "CSS: стили добавлены в $($cssFile.FullName)"
  }
} else {
  Write-Warning "CSS-файл не найден. Добавьте этот блок в свои стили вручную:"
  Write-Host $cssBlock
}

Write-Host ""
Write-Host "Готово. Резервные копии лежат рядом с файлами (*.bak-details)."
Write-Host "Дальше: запустите sync привычной командой, потом npm run dev и откройте /project/ekiden"
