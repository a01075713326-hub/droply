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