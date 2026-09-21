// Hand-checked data. Wins over data/verification.generated.ts,
// section by section. Never overwritten by any workflow — edit freely.
//
// Rules:
//   - anything marked "confirmed" must carry sourceUrl + checkedAt
//   - leaving a section out means "keep whatever the script found"
//   - to deliberately blank a section, pass [] and list it in `overrides`

import type { ManualVerification } from "./verification";

export const manualVerification: ManualVerification[] = [
  {
    slug: "example-project",
    checkedAt: "2026-09-18",
    links: [
      {
        kind: "website",
        url: "https://example.xyz",
        status: "confirmed",
        note: "Site links to the X account and the account links back",
        sourceUrl: "https://example.xyz",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
      {
        kind: "x",
        url: "https://x.com/exampleproject",
        status: "confirmed",
        sourceUrl: "https://x.com/exampleproject",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
    ],
    contracts: [
      {
        status: "not_found",
        note: "No token contract published yet",
        checkedAt: "2026-09-18",
        sourceLabel: "Manual",
      },
    ],
    audits: [
      {
        auditor: "Example Audits",
        reportUrl: "https://exampleaudits.io/reports/example.pdf",
        date: "2026-04-02",
        scope: "Staking contracts only, commit 8f21c0a",
        status: "confirmed",
        sourceUrl: "https://exampleaudits.io/reports/example.pdf",
        sourceLabel: "Example Audits",
        checkedAt: "2026-09-18",
      },
    ],
    signals: [
      {
        code: "anon_team",
        label: "Team members are named with photos and LinkedIn profiles",
        present: false,
        sourceUrl: "https://example.xyz/team",
        sourceLabel: "Manual",
        checkedAt: "2026-09-18",
      },
    ],
  },
];
