# redesign-cryptorank.ps1  (run from the project root, after add-cryptorank-details.ps1)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Read-Text($p)      { [System.IO.File]::ReadAllText($p, $enc) }
function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-redesign"
  if (-not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$syncPath = Join-Path $root "scripts\sync.js"
$detPath  = Join-Path $root "components\CryptoRankDetails.tsx"
$taskPath = Join-Path $root "components\CryptoRankTasks.tsx"
$pagePath = Join-Path $root 'app\project\[slug]\page.tsx'

foreach ($f in @($syncPath, $detPath, $pagePath)) {
  if (-not (Test-Path -LiteralPath $f)) { throw "Не найден файл: $f. Запустите скрипт из корня проекта." }
}

# ---------------------------------------------------------------
# 1. sync.js: real dates
# ---------------------------------------------------------------
$dateJs = @'
      // ---- real dates: prefer a real distribution date / task deadline ----
      {
        const today = new Date().toISOString().slice(0, 10);
        const upcomingEnds = (p.tasks || [])
          .map((t) => t.endDate)
          .filter((e) => e && e >= today)
          .sort();

        if (p.distributeDate) {
          p.date = p.distributeDate;
        } else if (upcomingEnds.length) {
          p.date = upcomingEnds[0];
        }
      }

'@

$sync = Read-Text $syncPath
if ($sync -notmatch 'get_activity_detail') {
  throw "sync.js: нет get_activity_detail. Сначала запустите add-cryptorank-details.ps1."
}

if ($sync -match 'real dates:') {
  Write-Host "sync.js: даты уже подключены, пропускаю"
} else {
  $m = [regex]::Match($sync, '[ \t]*return true;(?=\s*\};\s*let detailOk = 0;)')
  if (-not $m.Success) { throw "sync.js: не нашёл место для вставки дат (return true; перед let detailOk)." }
  Backup $syncPath
  $sync = $sync.Insert($m.Index, $dateJs)
  Write-Text $syncPath $sync
  Write-Host "sync.js: реальные даты подключены (date = дата распределения или ближайший дедлайн задачи)"
}

# ---------------------------------------------------------------
# 2. components/CryptoRankDetails.tsx (overview, full replacement)
# ---------------------------------------------------------------
$details = @'
import {
  ArrowUpRight,
  Banknote,
  BookOpen,
  Briefcase,
  CalendarDays,
  Clock,
  Code,
  Gauge,
  Gift,
  Layers,
  Link2,
  Lock,
  Network,
  Newspaper,
  Star,
  Users,
  Video,
  Wallet,
  Zap,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import type { Project } from "@/data/projects";

type Investor = {
  name?: string;
  tier?: number | null;
  category?: string;
  is_lead?: boolean;
};

type Tile = { icon: LucideIcon; label: string; value: string };

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

function niceLabel(value?: string): string {
  if (!value) return "";
  const t = value.replace(/[_-]+/g, " ").toLowerCase();
  return t.charAt(0).toUpperCase() + t.slice(1);
}

function linkIcon(label: string): LucideIcon {
  const l = label.toLowerCase();
  if (l.includes("gitbook") || l.includes("doc")) return BookOpen;
  if (l.includes("github")) return Code;
  if (l.includes("youtube") || l.includes("video")) return Video;
  if (l.includes("medium") || l.includes("blog") || l.includes("mirror")) return Newspaper;
  return Link2;
}

export default function CryptoRankDetails({ project: p }: { project: Project }) {
  const investors = (Array.isArray(p.topInvestors) ? p.topInvestors : []) as Investor[];
  const tasks = Array.isArray(p.tasks) ? p.tasks : [];
  const ecosystems = Array.isArray(p.ecosystems) ? p.ecosystems : [];
  const extraLinks = Array.isArray(p.extraLinks) ? p.extraLinks : [];

  const tiles: Tile[] = [];
  const tile = (icon: LucideIcon, label: string, value: unknown) => {
    if (value === undefined || value === null || value === "") return;
    tiles.push({ icon, label, value: String(value) });
  };

  const starts = tasks
    .map((t) => t.startDate)
    .filter((d): d is string => Boolean(d))
    .sort();
  const ends = tasks
    .map((t) => t.endDate)
    .filter((d): d is string => Boolean(d))
    .sort();

  tile(CalendarDays, "Opens", fmtDate(starts[0]));
  tile(CalendarDays, "Ends", fmtDate(ends[ends.length - 1]));
  tile(CalendarDays, "Distribution", fmtDate(p.distributeDate));
  tile(Gift, "Reward", p.rewardType);
  tile(Wallet, "Cost to farm", p.costToFarm);
  tile(Clock, "Time to farm", p.timeToFarm);
  tile(Star, "Rating", p.rating);
  tile(Zap, "Activity points", p.activityPoints);
  tile(Layers, "Category", p.category);
  tile(Banknote, "Total funding", compactUsd(p.funding));
  tile(Briefcase, "Investors", p.investorCount || null);
  tile(
    Users,
    "Twitter followers",
    p.twitterFollowers != null ? p.twitterFollowers.toLocaleString("en-US") : null
  );
  tile(Gauge, "Moni score", p.twitterScore);

  return (
    <section className="crx-card" aria-label="CryptoRank data">
      <header className="crx-head">
        <h2 className="crx-title">Overview</h2>
        <span className="crx-src">data from CryptoRank</span>
        {p.sourceUrl ? (
          <a className="crx-open" href={p.sourceUrl} target="_blank" rel="noreferrer">
            Open on CryptoRank <ArrowUpRight size={14} />
          </a>
        ) : null}
      </header>

      {p.noActiveTask != null || p.isAuthProtected != null ? (
        <div className="crx-flags">
          {p.noActiveTask != null ? (
            <span className={"crx-flag " + (p.noActiveTask ? "crx-flag--warn" : "crx-flag--ok")}>
              <span className="crx-dot" />
              {p.noActiveTask ? "No active task" : "Task active"}
            </span>
          ) : null}
          {p.isAuthProtected != null ? (
            <span className="crx-flag">
              <Lock size={12} />
              Auth protected: {p.isAuthProtected ? "yes" : "no"}
            </span>
          ) : null}
        </div>
      ) : null}

      {tiles.length ? (
        <div className="crx-tiles">
          {tiles.map((t) => {
            const Icon = t.icon;
            return (
              <div key={t.label} className="crx-tile">
                <span className="crx-tile__icon">
                  <Icon size={16} />
                </span>
                <span className="crx-tile__text">
                  <span className="crx-tile__label">{t.label}</span>
                  <strong className="crx-tile__value">{t.value}</strong>
                </span>
              </div>
            );
          })}
        </div>
      ) : null}

      {ecosystems.length ? (
        <div className="crx-group">
          <h3 className="crx-group__title">
            <Network size={14} /> Ecosystems
          </h3>
          <div className="crx-chips">
            {ecosystems.map((e) => (
              <span key={e} className="type-pill">{e}</span>
            ))}
          </div>
        </div>
      ) : null}

      {p.activityTypes && p.activityTypes.length ? (
        <div className="crx-group">
          <h3 className="crx-group__title">
            <Layers size={14} /> Activity types
          </h3>
          <div className="crx-chips">
            {p.activityTypes.map((t) => (
              <span key={t} className="type-pill">{t}</span>
            ))}
          </div>
        </div>
      ) : null}

      {extraLinks.length ? (
        <div className="crx-group">
          <h3 className="crx-group__title">
            <Link2 size={14} /> More links
          </h3>
          <div className="crx-chips">
            {extraLinks.map((l, i) => {
              const Icon = linkIcon(l.label);
              return (
                <a
                  key={l.url + i}
                  className="type-pill crx-linkchip"
                  href={l.url}
                  target="_blank"
                  rel="noreferrer noopener"
                >
                  <Icon size={13} />
                  {niceLabel(l.label)}
                </a>
              );
            })}
          </div>
        </div>
      ) : null}

      {investors.length ? (
        <div className="crx-group">
          <h3 className="crx-group__title">
            <Briefcase size={14} /> Top investors
            {p.investorCount ? " (" + investors.length + " of " + p.investorCount + ")" : ""}
          </h3>
          <ul className="crx-investors">
            {investors.map((inv, i) => (
              <li key={(inv.name ?? "investor") + i} className="crx-investor">
                <span className="crx-investor__name">{inv.name}</span>
                <span className="crx-investor__meta">
                  {inv.category ? <span>{inv.category}</span> : null}
                  {inv.tier != null ? <span className="crx-badge">Tier {inv.tier}</span> : null}
                  {inv.is_lead ? <span className="crx-badge crx-badge--new">Lead</span> : null}
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

Backup $detPath
Write-Text $detPath $details
Write-Host "CryptoRankDetails.tsx: новый обзор (плитки с иконками, даты, ссылки, инвесторы)"

# ---------------------------------------------------------------
# 3. components/CryptoRankTasks.tsx (new, client component)
# ---------------------------------------------------------------
$tasksTsx = @'
"use client";

import { useEffect, useState } from "react";
import { CalendarDays, Check, ExternalLink, ListChecks } from "lucide-react";
import type { ProjectTask } from "@/data/projects";

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
  if (start) return "From " + fmtDate(start);
  if (end) return "Until " + fmtDate(end);
  return "";
}

function niceLabel(value?: string): string {
  if (!value) return "";
  const t = value.replace(/[_-]+/g, " ").toLowerCase();
  return t.charAt(0).toUpperCase() + t.slice(1);
}

export default function CryptoRankTasks({
  tasks,
  slug,
  sourceUrl,
}: {
  tasks: ProjectTask[];
  slug: string;
  sourceUrl?: string;
}) {
  const storageKey = "droply:crx-tasks:" + slug;
  const [done, setDone] = useState<Record<string, boolean>>({});

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(storageKey);
      if (raw) setDone(JSON.parse(raw));
    } catch {
      // storage unavailable - progress just won't persist
    }
  }, [storageKey]);

  const toggle = (id: string) => {
    setDone((prev) => {
      const next = { ...prev, [id]: !prev[id] };
      try {
        window.localStorage.setItem(storageKey, JSON.stringify(next));
      } catch {
        // ignore
      }
      return next;
    });
  };

  const total = tasks.length;
  const completed = tasks.filter((t, i) => done[String(t.id ?? i)]).length;
  const percent = total ? Math.round((completed / total) * 100) : 0;

  return (
    <div className="crx-tasks">
      <div className="crx-tasks__head">
        <h2 className="crx-tasks__title">
          <ListChecks size={20} /> Tasks
        </h2>
        <span className="crx-tasks__progress">
          {completed}/{total} done
        </span>
      </div>

      <div className="crx-progress" aria-hidden="true">
        <span style={{ width: percent + "%" }} />
      </div>

      <ol className="crx-steps">
        {tasks.map((t, i) => {
          const id = String(t.id ?? i);
          const isDone = !!done[id];
          const dates = taskDates(t.startDate, t.endDate);
          const isOpen = String(t.status || "").toUpperCase() === "OPEN";

          return (
            <li key={id} className={"crx-step" + (isDone ? " is-done" : "")}>
              <button
                type="button"
                className="crx-step__check"
                onClick={() => toggle(id)}
                aria-pressed={isDone}
                aria-label={(isDone ? "Mark as not done: " : "Mark as done: ") + t.title}
              >
                {isDone ? <Check size={14} /> : <span>{i + 1}</span>}
              </button>

              <div className="crx-step__body">
                <div className="crx-step__top">
                  <span className="crx-step__title">{t.title}</span>
                  <span className="crx-step__badges">
                    {t.isNew ? <span className="crx-badge crx-badge--new">New</span> : null}
                    {t.exclusive ? <span className="crx-badge crx-badge--excl">Exclusive</span> : null}
                    {t.status ? (
                      <span className={"crx-badge" + (isOpen ? " crx-badge--open" : "")}>
                        {niceLabel(t.status)}
                      </span>
                    ) : null}
                  </span>
                </div>

                {dates ? (
                  <div className="crx-step__dates">
                    <CalendarDays size={13} /> {dates}
                  </div>
                ) : null}

                {t.types && t.types.length ? (
                  <div className="crx-step__types">
                    {t.types.map((ty) => (
                      <span key={ty} className="type-pill">{ty}</span>
                    ))}
                  </div>
                ) : null}
              </div>
            </li>
          );
        })}
      </ol>

      {sourceUrl ? (
        <a className="crx-steps__more" href={sourceUrl} target="_blank" rel="noreferrer">
          Full instructions on CryptoRank <ExternalLink size={14} />
        </a>
      ) : null}
    </div>
  );
}
'@

Write-Text $taskPath $tasksTsx
Write-Host "CryptoRankTasks.tsx: создан (шаги с чекбоксами и прогрессом)"

# ---------------------------------------------------------------
# 4. app/project/[slug]/page.tsx: tasks go to the left column
# ---------------------------------------------------------------
$page = Read-Text $pagePath

if ($page -match 'CryptoRankTasks') {
  Write-Host "page.tsx: уже подключено, пропускаю"
} else {
  $impAnchor = 'import CryptoRankDetails from "@/components/CryptoRankDetails";'
  if (-not $page.Contains($impAnchor)) { throw "page.tsx: не нашёл import CryptoRankDetails." }

  $condOld = '{(p.actions && p.actions.length) || official.length || social.length ? ('
  if (-not $page.Contains($condOld)) { throw "page.tsx: не нашёл условие guide-layout." }

  $stepsPattern = '(?s)\{p\.actions && p\.actions\.length \? \(\s*<section className="article-card guide-layout__steps">\s*<GuideSteps actions=\{p\.actions\} slug=\{p\.slug\} />\s*</section>\s*\) : null\}'
  $sm = [regex]::Match($page, $stepsPattern)
  if (-not $sm.Success) { throw "page.tsx: не нашёл блок GuideSteps." }

  $stepsNew = @'
{p.actions && p.actions.length ? (
            <section className="article-card guide-layout__steps">
              <GuideSteps actions={p.actions} slug={p.slug} />
            </section>
          ) : isCryptoRank && p.tasks && p.tasks.length ? (
            <section className="article-card guide-layout__steps">
              <CryptoRankTasks tasks={p.tasks} slug={p.slug} sourceUrl={p.sourceUrl} />
            </section>
          ) : null}
'@

  $condNew = '{(p.actions && p.actions.length) || (isCryptoRank && p.tasks && p.tasks.length) || official.length || social.length ? ('

  Backup $pagePath
  # replace the later occurrence first so earlier indexes stay valid
  $page = $page.Substring(0, $sm.Index) + $stepsNew.TrimEnd() + $page.Substring($sm.Index + $sm.Length)
  $page = $page.Replace($condOld, $condNew)
  $page = $page.Replace($impAnchor, $impAnchor + "`n" + 'import CryptoRankTasks from "@/components/CryptoRankTasks";')
  Write-Text $pagePath $page
  Write-Host "page.tsx: задачи CryptoRank выводятся слева, ссылки справа"
}

# ---------------------------------------------------------------
# 5. CSS
# ---------------------------------------------------------------
$cssBlock = @'

/* --- CryptoRank redesign (redesign-cryptorank) --- */
.crx-card,
.crx-tasks {
  --crx-border: rgba(255, 255, 255, 0.09);
  --crx-surface: rgba(255, 255, 255, 0.04);
  --crx-surface-2: rgba(255, 255, 255, 0.08);
  --crx-muted: rgba(255, 255, 255, 0.62);
  --crx-accent: #b794f6;
  --crx-accent-bg: rgba(167, 139, 250, 0.16);
  --crx-good: #4ade80;
  --crx-good-bg: rgba(74, 222, 128, 0.14);
  --crx-warn: #fbbf24;
  --crx-warn-bg: rgba(251, 191, 36, 0.14);
}

.crx-card {
  display: grid;
  gap: 20px;
  padding: 22px;
  margin: 18px 0;
  border: 1px solid var(--crx-border);
  border-radius: 20px;
  background: var(--crx-surface);
  backdrop-filter: blur(8px);
}

.crx-head { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.crx-title { margin: 0; font-size: 20px; }
.crx-src { color: var(--crx-muted); font-size: 13px; }
.crx-open {
  margin-left: auto;
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--crx-accent);
  font-weight: 600;
  font-size: 14px;
  text-decoration: none;
}
.crx-open:hover { text-decoration: underline; }

.crx-flags { display: flex; gap: 8px; flex-wrap: wrap; }
.crx-flag {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 11px;
  border-radius: 999px;
  border: 1px solid var(--crx-border);
  background: var(--crx-surface);
  font-size: 13px;
}
.crx-flag--ok { color: var(--crx-good); background: var(--crx-good-bg); border-color: transparent; }
.crx-flag--warn { color: var(--crx-warn); background: var(--crx-warn-bg); border-color: transparent; }
.crx-dot { width: 7px; height: 7px; border-radius: 50%; background: currentColor; }

.crx-tiles {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
  gap: 10px;
}
.crx-tile {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px 14px;
  border: 1px solid var(--crx-border);
  border-radius: 14px;
  background: var(--crx-surface);
}
.crx-tile__icon {
  flex: 0 0 auto;
  width: 34px;
  height: 34px;
  display: grid;
  place-items: center;
  border-radius: 10px;
  color: var(--crx-accent);
  background: var(--crx-accent-bg);
}
.crx-tile__text { display: grid; gap: 2px; min-width: 0; }
.crx-tile__label { color: var(--crx-muted); font-size: 12px; }
.crx-tile__value { font-size: 16px; overflow-wrap: anywhere; }

.crx-group { display: grid; gap: 10px; }
.crx-group__title {
  display: flex;
  align-items: center;
  gap: 7px;
  margin: 0;
  color: var(--crx-muted);
  font-size: 12px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.crx-chips { display: flex; flex-wrap: wrap; gap: 8px; }
.crx-linkchip { display: inline-flex; align-items: center; gap: 6px; text-decoration: none; }

.crx-investors {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 8px;
}
.crx-investor {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid var(--crx-border);
  border-radius: 12px;
  background: var(--crx-surface);
}
.crx-investor__name { font-weight: 600; }
.crx-investor__meta { display: inline-flex; align-items: center; gap: 6px; color: var(--crx-muted); font-size: 12px; }

.crx-badge {
  display: inline-block;
  padding: 3px 9px;
  border-radius: 999px;
  background: var(--crx-surface-2);
  font-size: 12px;
  font-weight: 600;
  white-space: nowrap;
}
.crx-badge--open { color: var(--crx-good); background: var(--crx-good-bg); }
.crx-badge--new { color: var(--crx-accent); background: var(--crx-accent-bg); }
.crx-badge--excl { color: var(--crx-warn); background: var(--crx-warn-bg); }

/* tasks as steps */
.crx-tasks { display: grid; gap: 14px; }
.crx-tasks__head { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
.crx-tasks__title { display: flex; align-items: center; gap: 9px; margin: 0; font-size: 22px; }
.crx-tasks__progress { color: var(--crx-muted); font-size: 13px; }
.crx-progress { height: 6px; border-radius: 999px; background: var(--crx-surface-2); overflow: hidden; }
.crx-progress > span {
  display: block;
  height: 100%;
  background: linear-gradient(90deg, #8b5cf6, #c084fc);
  transition: width 0.25s ease;
}
.crx-steps { list-style: none; margin: 0; padding: 0; display: grid; gap: 10px; }
.crx-step {
  display: flex;
  gap: 14px;
  padding: 14px;
  border: 1px solid var(--crx-border);
  border-radius: 14px;
  background: var(--crx-surface);
  transition: opacity 0.2s ease;
}
.crx-step.is-done { opacity: 0.55; }
.crx-step.is-done .crx-step__title { text-decoration: line-through; }
.crx-step__check {
  flex: 0 0 auto;
  width: 30px;
  height: 30px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  border: 1px solid var(--crx-border);
  background: var(--crx-surface-2);
  color: var(--crx-muted);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}
.crx-step__check:hover { border-color: var(--crx-accent); color: var(--crx-accent); }
.crx-step.is-done .crx-step__check { background: var(--crx-accent); border-color: var(--crx-accent); color: #120a24; }
.crx-step__body { display: grid; gap: 8px; min-width: 0; flex: 1; }
.crx-step__top { display: flex; align-items: flex-start; justify-content: space-between; gap: 10px; flex-wrap: wrap; }
.crx-step__title { font-weight: 600; font-size: 16px; }
.crx-step__badges { display: inline-flex; gap: 6px; flex-wrap: wrap; }
.crx-step__dates { display: inline-flex; align-items: center; gap: 6px; color: var(--crx-muted); font-size: 13px; }
.crx-step__types { display: flex; flex-wrap: wrap; gap: 6px; }
.crx-steps__more {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  color: var(--crx-accent);
  font-size: 14px;
  font-weight: 600;
  text-decoration: none;
}
.crx-steps__more:hover { text-decoration: underline; }

@media (max-width: 560px) {
  .crx-card { padding: 16px; }
  .crx-tiles { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .crx-tile { padding: 10px; gap: 8px; }
  .crx-open { margin-left: 0; }
}
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
  if ($css -match 'crx-tasks__title') {
    Write-Host "CSS: новые стили уже есть, пропускаю"
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
Write-Host "Готово. Резервные копии: *.bak-redesign"
Write-Host "Дальше: запустите sync (даты берутся при синхронизации), затем npm run dev и откройте /project/ekiden"
