"use client";

import { useEffect, useState } from "react";
import { Check } from "lucide-react";

// Guide steps come from the parser as "title\u2029body" (or just a
// bare string for legacy/unsplit data). Links inside the body are
// written as "[label](url)" so we can render real <a> tags.
const STEP_SEP = "\u2029";
const LINK_RE = /(\[[^\]]+\]\([^)]+\))/g;
const LINK_MATCH_RE = /^\[([^\]]+)\]\(([^)]+)\)$/;

function renderWithLinks(text: string) {
  return text.split(LINK_RE).map((part, i) => {
    const match = part.match(LINK_MATCH_RE);

    if (match) {
      return (
        <a
          key={i}
          href={match[2]}
          target="_blank"
          rel="noreferrer"
          className="step-link"
        >
          {match[1]}
        </a>
      );
    }

    return part ? <span key={i}>{part}</span> : null;
  });
}

export default function GuideSteps({
  actions,
  slug,
}: {
  actions: string[];
  slug: string;
}) {
  const [checked, setChecked] = useState<boolean[]>(() =>
    actions.map(() => false)
  );

  const storageKey = `droply-steps-${slug}`;

  useEffect(() => {
    try {
      const saved = localStorage.getItem(storageKey);

      if (saved) {
        const parsed = JSON.parse(saved);

        if (Array.isArray(parsed) && parsed.length === actions.length) {
          setChecked(parsed);
          return;
        }
      }
    } catch {
      // ignore malformed/blocked storage — steps just start unchecked
    }

    setChecked(actions.map(() => false));
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [slug, actions.length]);

  const toggle = (index: number) => {
    setChecked((prev) => {
      const next = [...prev];
      next[index] = !next[index];

      try {
        localStorage.setItem(storageKey, JSON.stringify(next));
      } catch {
        // ignore — nothing to persist to, still works this session
      }

      return next;
    });
  };

  const done = checked.filter(Boolean).length;
  const total = actions.length;
  const pct = total ? Math.round((done / total) * 100) : 0;

  return (
    <div className="guide-steps">
      <div className="guide-progress">
        <div className="guide-progress-bar">
          <div className="guide-progress-fill" style={{ width: `${pct}%` }} />
        </div>
        <span>
          {done} / {total} STEPS COMPLETED
        </span>
      </div>

      <ol className="guide-list">
        {actions.map((action, i) => {
          const sepIndex = action.indexOf(STEP_SEP);
          const hasTitle = sepIndex >= 0;
          const rawTitle = hasTitle ? action.slice(0, sepIndex) : "";
          const body = hasTitle ? action.slice(sepIndex + 1) : action;

          const title =
            rawTitle && !/^step\s*\d+/i.test(rawTitle)
              ? `Step ${i + 1}: ${rawTitle}`
              : rawTitle;

          const isDone = checked[i];

          return (
            <li
              key={i}
              className={`guide-step${isDone ? " done" : ""}`}
              onClick={() => toggle(i)}
            >
              <span className="guide-checkbox" aria-hidden="true">
                {isDone ? <Check size={13} strokeWidth={3} /> : null}
              </span>
              <div className="guide-step-text">
                {title ? <strong>{renderWithLinks(title)}</strong> : null}
                <p>{renderWithLinks(body)}</p>
              </div>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
