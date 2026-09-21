# redesign-cryptorank-2.ps1  (run from the project root, after redesign-cryptorank.ps1)
$ErrorActionPreference = "Stop"
$root = (Get-Location).Path
$enc  = New-Object System.Text.UTF8Encoding($false)

function Read-Text($p)      { [System.IO.File]::ReadAllText($p, $enc) }
function Write-Text($p, $t) { [System.IO.File]::WriteAllText($p, $t, $enc) }
function Backup($p) {
  $b = "$p.bak-redesign2"
  if (-not (Test-Path -LiteralPath $b)) { Copy-Item -LiteralPath $p -Destination $b }
}

$syncPath  = Join-Path $root "scripts\sync.js"
$typesPath = Join-Path $root "data\projects.ts"
$detPath   = Join-Path $root "components\CryptoRankDetails.tsx"
$taskPath  = Join-Path $root "components\CryptoRankTasks.tsx"

foreach ($f in @($syncPath, $typesPath, $detPath, $taskPath)) {
  if (-not (Test-Path -LiteralPath $f)) { throw "Не найден файл: $f. Сначала запустите предыдущие скрипты (add-cryptorank-details.ps1 и redesign-cryptorank.ps1) из корня проекта." }
}

# ---------------------------------------------------------------
# 1. sync.js: task instructions -> safe plain-text lines
# ---------------------------------------------------------------
$helperJs = @'
    // Converts task instructions (HTML) into plain-text lines.
    // Only text and http(s) links survive: links become "[label](url)",
    // images, scripts and all other markup are dropped.
    const htmlToLines = (html) => {
      let s = String(html || "");
      if (!s.trim()) return undefined;

      s = s
        .replace(/<(script|style)\b[\s\S]*?<\/\1>/gi, " ")
        .replace(/<img\b[^>]*>/gi, " ");

      s = s.replace(
        /<a\b[^>]*?href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi,
        (_, href, inner) => {
          const label = inner
            .replace(/<[^>]+>/g, " ")
            .replace(/\s+/g, " ")
            .trim()
            .replace(/[\[\]]/g, "");
          const url = safeUrl(decode(href)).replace(/\)/g, "%29");

          if (!url) return label;
          return label ? `[${label}](${url})` : url;
        }
      );

      s = s.replace(/<ol\b[^>]*>([\s\S]*?)<\/ol>/gi, (_, inner) => {
        let n = 0;
        return (
          "\n" + inner.replace(/<li\b[^>]*>/gi, () => `\n${++n}. `) + "\n"
        );
      });

      s = s
        .replace(/<li\b[^>]*>/gi, "\n\u2022 ")
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<\/(p|div|li|h[1-6]|ul|ol|tr|table|blockquote)>/gi, "\n")
        .replace(/<[^>]+>/g, " ");

      const lines = decode(s)
        .split(/\r?\n/)
        .map((l) => l.replace(/\s+/g, " ").trim())
        .filter((l) => l && l !== "\u2022");

      if (!lines.length) return undefined;

      return lines.slice(0, 60).map((l) => l.slice(0, 1200));
    };

'@

$sync = Read-Text $syncPath
if ($sync -notmatch 'get_activity_detail') {
  throw "sync.js: нет get_activity_detail. Сначала запустите add-cryptorank-details.ps1."
}

if ($sync -match 'htmlToLines') {
  Write-Host "sync.js: инструкции уже подключены, пропускаю"
} else {
  $anchor = '// Copies useful fields from the detail response onto the project.'
  $idx = $sync.IndexOf($anchor)
  if ($idx -lt 0) { throw "sync.js: не нашёл место для вставки htmlToLines." }

  $fieldAnchor = 'exclusive: t?.exclusive === true ? true : undefined,'
  if (-not $sync.Contains($fieldAnchor)) { throw "sync.js: не нашёл поле exclusive в задачах." }

  Backup $syncPath
  $lineStart = $sync.LastIndexOf("`n", $idx) + 1
  $sync = $sync.Insert($lineStart, $helperJs)
  $sync = $sync.Replace($fieldAnchor, $fieldAnchor + "`n            instructions: htmlToLines(t?.description_html),")
  $sync = $sync.Replace(
    '// description / description_html (third-party HTML) are NOT stored.',
    '// Raw HTML is never stored: task instructions are reduced to text lines with http(s) links.'
  )
  Write-Text $syncPath $sync
  Write-Host "sync.js: инструкции задач подключены (текст + ссылки, без картинок и HTML)"
}

# ---------------------------------------------------------------
# 2. data/projects.ts: instructions field
# ---------------------------------------------------------------
$types = Read-Text $typesPath
if ($types -match 'instructions\?: string\[\]') {
  Write-Host "projects.ts: поле instructions уже есть, пропускаю"
} else {
  $t0 = $types.IndexOf('export type ProjectTask = {')
  if ($t0 -lt 0) { throw "projects.ts: не нашёл ProjectTask. Сначала запустите add-cryptorank-details.ps1." }
  $marker = '  exclusive?: boolean;'
  $t1 = $types.IndexOf($marker, $t0)
  if ($t1 -lt 0) { throw "projects.ts: не нашёл exclusive в ProjectTask." }

  Backup $typesPath
  $types = $types.Insert($t1 + $marker.Length, "`n  instructions?: string[];")
  Write-Text $typesPath $types
  Write-Host "projects.ts: добавлено instructions?: string[]"
}

# ---------------------------------------------------------------
# 3. components/CryptoRankDetails.tsx
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

function XIcon({ size = 14 }: { size?: number }) {
  return (
    <svg viewBox="0 0 24 24" width={size} height={size} aria-hidden="true" fill="currentColor">
      <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
    </svg>
  );
}

function compactNumber(n: number): string {
  return new Intl.NumberFormat("en-US", {
    notation: "compact",
    maximumFractionDigits: 1,
  }).format(n);
}

function compactUsd(value?: string): string | null {
  if (!value) return null;
  const n = Number(String(value).replace(/[^0-9.]/g, ""));
  if (!Number.isFinite(n) || n <= 0) return value;
  return "$" + compactNumber(n);
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

  const followers = p.twitterFollowers;
  const xHref = p.x && /^https?:\/\//i.test(p.x) ? p.x : undefined;
  const xInner = (
    <>
      <XIcon size={15} />
      <strong>{followers != null ? compactNumber(followers) : ""}</strong>
      <span>followers</span>
    </>
  );

  const hasTopbar =
    p.twitterScore != null ||
    followers != null ||
    p.noActiveTask != null ||
    p.isAuthProtected != null;

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

      {hasTopbar ? (
        <div className="crx-topbar">
          {p.twitterScore != null ? (
            <div className="crx-moni" title="Moni score">
              <span className="crx-moni__logo">
                <Gauge size={20} />
              </span>
              <span className="crx-moni__text">
                <span className="crx-moni__label">Moni score</span>
                <strong className="crx-moni__value">
                  {Number(p.twitterScore).toLocaleString("en-US")}
                </strong>
              </span>
            </div>
          ) : null}

          {followers != null ? (
            xHref ? (
              <a
                className="crx-xbadge"
                href={xHref}
                target="_blank"
                rel="noreferrer noopener"
                title={followers.toLocaleString("en-US") + " followers on X"}
              >
                {xInner}
              </a>
            ) : (
              <span
                className="crx-xbadge"
                title={followers.toLocaleString("en-US") + " followers on X"}
              >
                {xInner}
              </span>
            )
          ) : null}

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
Write-Host "CryptoRankDetails.tsx: Moni-бейдж, значок X с подписчиками"

# ---------------------------------------------------------------
# 4. components/CryptoRankTasks.tsx
# ---------------------------------------------------------------
$tasksTsx = @'
"use client";

import { useEffect, useState } from "react";
import type { ReactNode } from "react";
import { CalendarDays, Check, ChevronDown, ExternalLink, ListChecks } from "lucide-react";
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

// "[label](https://url)" and bare https://url links become highlighted anchors.
// Only http(s) URLs are ever turned into links; everything else stays plain text.
const INLINE_RE = /\[([^\]]+)\]\((https?:\/\/[^\s)]+)\)|(https?:\/\/[^\s<>()[\]]+)/g;

function prettyUrl(url: string): string {
  const s = url.replace(/^https?:\/\/(www\.)?/i, "").replace(/\/$/, "");
  return s.length > 42 ? s.slice(0, 41) + "\u2026" : s;
}

function renderInline(text: string): ReactNode[] {
  const out: ReactNode[] = [];
  const re = new RegExp(INLINE_RE.source, "g");
  let last = 0;
  let key = 0;
  let m: RegExpExecArray | null;

  while ((m = re.exec(text)) !== null) {
    if (m.index > last) out.push(text.slice(last, m.index));

    let href = m[2] || m[3] || "";
    let label = m[1] || "";
    let tail = "";

    if (!m[1]) {
      const t = href.match(/[.,;:!?]+$/);
      if (t) {
        tail = t[0];
        href = href.slice(0, href.length - tail.length);
      }
      label = prettyUrl(href);
    }

    out.push(
      <a key={key++} className="crx-link" href={href} target="_blank" rel="noreferrer noopener">
        {label}
        <ExternalLink size={11} />
      </a>
    );
    if (tail) out.push(tail);
    last = m.index + m[0].length;
  }

  if (last < text.length) out.push(text.slice(last));
  return out;
}

function Manual({ lines }: { lines: string[] }) {
  return (
    <div className="crx-manual">
      {lines.map((line, idx) => {
        const num = line.match(/^(\d+)\.\s+(.*)$/);
        const bullet = line.match(/^\u2022\s+(.*)$/);

        if (num) {
          return (
            <div key={idx} className="crx-line crx-line--row">
              <span className="crx-line__mark crx-line__mark--num">{num[1]}</span>
              <span>{renderInline(num[2])}</span>
            </div>
          );
        }

        if (bullet) {
          return (
            <div key={idx} className="crx-line crx-line--row">
              <span className="crx-line__mark crx-line__mark--dot" />
              <span>{renderInline(bullet[1])}</span>
            </div>
          );
        }

        return (
          <p key={idx} className="crx-line">
            {renderInline(line)}
          </p>
        );
      })}
    </div>
  );
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
  const [openIds, setOpenIds] = useState<Record<string, boolean>>({});

  useEffect(() => {
    try {
      const raw = window.localStorage.getItem(storageKey);
      if (raw) setDone(JSON.parse(raw));
    } catch {
      // storage unavailable - progress just won't persist
    }
  }, [storageKey]);

  const toggleDone = (id: string) => {
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
          const lines = Array.isArray(t.instructions) ? t.instructions : [];
          const manualOpen = openIds[id] ?? total === 1;

          return (
            <li key={id} className={"crx-step" + (isDone ? " is-done" : "")}>
              <button
                type="button"
                className="crx-step__check"
                onClick={() => toggleDone(id)}
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

                {lines.length ? (
                  <>
                    <button
                      type="button"
                      className="crx-toggle"
                      aria-expanded={manualOpen}
                      onClick={() => setOpenIds((prev) => ({ ...prev, [id]: !manualOpen }))}
                    >
                      {manualOpen ? "Hide instructions" : "Show instructions"}
                      <ChevronDown size={14} />
                    </button>
                    {manualOpen ? <Manual lines={lines} /> : null}
                  </>
                ) : null}
              </div>
            </li>
          );
        })}
      </ol>

      {sourceUrl ? (
        <a className="crx-steps__more" href={sourceUrl} target="_blank" rel="noreferrer">
          Source: CryptoRank <ExternalLink size={14} />
        </a>
      ) : null}
    </div>
  );
}
'@

Backup $taskPath
Write-Text $taskPath $tasksTsx
Write-Host "CryptoRankTasks.tsx: инструкции с подсветкой ссылок, сворачивание"

# ---------------------------------------------------------------
# 5. CSS
# ---------------------------------------------------------------
$cssBlock = @'

/* --- CryptoRank redesign 2 (redesign-cryptorank-2) --- */
.crx-topbar { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }

.crx-moni {
  display: inline-flex;
  align-items: center;
  gap: 12px;
  padding: 8px 20px 8px 8px;
  border-radius: 16px;
  border: 1px solid rgba(34, 211, 238, 0.3);
  background: linear-gradient(135deg, rgba(34, 211, 238, 0.12), rgba(139, 92, 246, 0.18));
}
.crx-moni__logo {
  width: 42px;
  height: 42px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  color: #fff;
  background: linear-gradient(135deg, #22d3ee, #8b5cf6);
  box-shadow: 0 0 18px rgba(34, 211, 238, 0.35);
}
.crx-moni__text { display: grid; line-height: 1.15; }
.crx-moni__label { font-size: 11px; color: var(--crx-muted); text-transform: uppercase; letter-spacing: 0.06em; }
.crx-moni__value { font-size: 24px; }

.crx-xbadge {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 10px 14px;
  border-radius: 14px;
  border: 1px solid var(--crx-border);
  background: var(--crx-surface);
  color: inherit;
  text-decoration: none;
  font-size: 14px;
}
.crx-xbadge strong { font-size: 16px; }
.crx-xbadge span { color: var(--crx-muted); font-size: 12px; }
a.crx-xbadge:hover { border-color: var(--crx-accent); }

.crx-toggle {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  width: fit-content;
  padding: 0;
  border: 0;
  background: none;
  color: var(--crx-accent);
  font-weight: 600;
  font-size: 13px;
  cursor: pointer;
}
.crx-toggle svg { transition: transform 0.2s ease; }
.crx-toggle[aria-expanded="true"] svg { transform: rotate(180deg); }

.crx-manual {
  display: grid;
  gap: 8px;
  padding: 12px 14px;
  border-radius: 12px;
  border-left: 3px solid var(--crx-accent);
  background: rgba(255, 255, 255, 0.03);
  font-size: 14px;
  line-height: 1.55;
}
.crx-line { margin: 0; }
.crx-line--row { display: flex; gap: 10px; align-items: flex-start; }
.crx-line__mark { flex: 0 0 auto; margin-top: 2px; }
.crx-line__mark--num {
  width: 20px;
  height: 20px;
  display: grid;
  place-items: center;
  border-radius: 50%;
  background: var(--crx-accent-bg);
  color: var(--crx-accent);
  font-size: 11px;
  font-weight: 700;
}
.crx-line__mark--dot {
  width: 6px;
  height: 6px;
  margin: 9px 7px 0 7px;
  border-radius: 50%;
  background: var(--crx-accent);
}

.crx-link {
  color: var(--crx-accent);
  font-weight: 600;
  text-decoration: underline;
  text-underline-offset: 3px;
  text-decoration-color: rgba(183, 148, 246, 0.45);
  overflow-wrap: anywhere;
}
.crx-link:hover { text-decoration-color: currentColor; }
.crx-link svg { display: inline; vertical-align: -1px; margin-left: 3px; }
'@

$cssFile = Get-ChildItem -Path $root -Recurse -Filter *.css -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch '\\(node_modules|\.next)\\' } |
  Where-Object { Select-String -Path $_.FullName -Pattern 'crx-tasks__title' -Quiet } |
  Select-Object -First 1

if (-not $cssFile) { throw "CSS: не нашёл файл со стилями crx-*. Сначала запустите redesign-cryptorank.ps1." }

$css = Read-Text $cssFile.FullName
if ($css -match 'crx-moni__logo') {
  Write-Host "CSS: стили уже добавлены, пропускаю"
} else {
  Backup $cssFile.FullName
  Write-Text $cssFile.FullName ($css.TrimEnd() + "`n" + $cssBlock)
  Write-Host "CSS: стили добавлены в $($cssFile.FullName)"
}

Write-Host ""
Write-Host "Готово. Резервные копии: *.bak-redesign2"
Write-Host "Дальше: запустите sync (инструкции подтягиваются при синхронизации), затем npm run dev"
