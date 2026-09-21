"use client";

import { useEffect, useState } from "react";
import { Check, ArrowLeft, ArrowRight } from "lucide-react";

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

/** Strips a leading "Step 3: " / "Step 3 -" prefix so the nav list and
 * the detail heading can show a clean, short label on their own. */
function cleanTitle(raw: string, i: number) {
  if (!raw) return `Step ${i + 1}`;
  const stripped = raw.replace(/^step\s*\d+\s*[:.\-]?\s*/i, "").trim();
  return stripped || `Step ${i + 1}`;
}

export default function GuideSteps({
  actions,
  slug,
}: {
  actions: string[];
  slug: string;
}) {
  const parsed = actions.map((action, i) => {
    const sepIndex = action.indexOf(STEP_SEP);
    const hasTitle = sepIndex >= 0;
    const rawTitle = hasTitle ? action.slice(0, sepIndex) : "";
    const body = hasTitle ? action.slice(sepIndex + 1) : action;
    return { title: cleanTitle(rawTitle, i), body };
  });

  const [checked, setChecked] = useState<boolean[]>(() =>
    actions.map(() => false)
  );
  const [active, setActive] = useState(0);

  const storageKey = `droply-steps-${slug}`;

  useEffect(() => {
    try {
      const saved = localStorage.getItem(storageKey);

      if (saved) {
        const p = JSON.parse(saved);

        if (Array.isArray(p) && p.length === actions.length) {
          setChecked(p);
          setActive(0);
          return;
        }
      }
    } catch {
      // ignore malformed/blocked storage — steps just start unchecked
    }

    setChecked(actions.map(() => false));
    setActive(0);
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
  const step = parsed[active];

  if (!total) return null;

  return (
    <div className="guide-card">
      <div className="guide-head">
        <h2>How to participate</h2>
        <span className="guide-count">
          {done} / {total} steps
        </span>
      </div>

      <div className="guide-progress-track">
        <div className="guide-progress-fill" style={{ width: `${pct}%` }} />
      </div>

      <div className="guide-body">
        <ol className="guide-nav">
          {parsed.map((s, i) => (
            <li
              key={i}
              className={`guide-nav-item${i === active ? " active" : ""}${
                checked[i] ? " done" : ""
              }`}
              onClick={() => setActive(i)}
            >
              <span className="guide-nav-num" aria-hidden="true">
                {checked[i] ? <Check size={12} strokeWidth={3} /> : i + 1}
              </span>
              <span className="guide-nav-label">{s.title}</span>
            </li>
          ))}
        </ol>

        <div className="guide-detail">
          <div className="guide-detail-kicker">
            Step {active + 1} of {total}
          </div>
          <h3 className="guide-detail-title">{step.title}</h3>
          <p className="guide-detail-body">{renderWithLinks(step.body)}</p>

          <div className="guide-detail-actions">
            <button
              type="button"
              className={`guide-btn${checked[active] ? " guide-btn--done" : ""}`}
              onClick={() => toggle(active)}
            >
              {checked[active] ? "Marked as done" : "Mark as done"}
            </button>
          </div>

          <div className="guide-detail-nav">
            <button
              type="button"
              className="guide-nav-btn"
              onClick={() => setActive((a) => Math.max(0, a - 1))}
              disabled={active === 0}
              aria-label="Previous step"
            >
              <ArrowLeft size={16} />
            </button>
            <button
              type="button"
              className="guide-nav-btn"
              onClick={() => setActive((a) => Math.min(total - 1, a + 1))}
              disabled={active === total - 1}
              aria-label="Next step"
            >
              <ArrowRight size={16} />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
