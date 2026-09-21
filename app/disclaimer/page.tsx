import type { Metadata } from "next";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Disclaimer",
  description: "Droply is not financial advice. Airdrops are speculative and data may be outdated.",
  alternates: { canonical: "/disclaimer" },
};

export default function DisclaimerPage() {
  return (
    <main className="page container legal-page">
      <article className="article-card legal-card">
        <h1>Disclaimer</h1>

        <h2>Not financial advice</h2>
        <p>
          Everything on Droply is provided for information only. It is not financial, investment,
          legal or tax advice, and it is not a recommendation to take part in any project. You are
          responsible for your own decisions.
        </p>

        <h2>Airdrops are speculative</h2>
        <p>
          A listed airdrop, points programme or campaign does not guarantee a token, a reward or any
          value. Points are not tokens, and projects can change or cancel their plans at any time.
          Farming can cost money in fees and time, and you can lose funds.
        </p>

        <h2>Scams and wallet safety</h2>
        <ul>
          <li>Never share your seed phrase or private keys with anyone.</li>
          <li>Reach a project only through links you have confirmed on its official channels.</li>
          <li>Read what a transaction does before you sign it, and be careful with token approvals.</li>
          <li>Use a separate wallet for experiments when you can.</li>
        </ul>

        <h2>Data may be wrong or outdated</h2>
        <p>
          Data is collected automatically from public sources and may be incomplete, delayed or
          incorrect. Dates, requirements and rewards can change without notice. Always confirm
          details with the official sources of the project.
        </p>

        <h2>Automated risk level</h2>
        <p>
          The verification block and risk level on project pages come from automated checks of
          public data. They can miss problems, and a low score does not mean a project is safe.
        </p>

        <h2>Third-party links</h2>
        <p>
          Droply links to websites we do not control. We are not responsible for their content or
          for what happens when you use them. Links labelled as sponsored may earn us a commission.
        </p>

        <h2>Liability</h2>
        <p>
          You use Droply at your own risk. To the extent permitted by law, we are not liable for
          losses that result from using the information on this site.
        </p>

        <p className="legal-updated">Last updated: {SITE.updated}</p>
      </article>
    </main>
  );
}