import type { Metadata } from "next";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Contact",
  description: "How to contact Droply: corrections, project owners, partnerships.",
  alternates: { canonical: "/contact" },
};

export default function ContactPage() {
  return (
    <main className="page container legal-page">
      <article className="article-card legal-card">
        <h1>Contact</h1>
        <p>Use these channels to:</p>
        <ul>
          <li>report a mistake or an outdated detail on a project page;</li>
          <li>request a correction or removal if you represent a project;</li>
          <li>ask about partnerships.</li>
        </ul>

        <h2>Where to write</h2>
        <ul>
          {SITE.email ? (
            <li>
              Email: <a href={`mailto:${SITE.email}`}>{SITE.email}</a>
            </li>
          ) : null}
          {SITE.telegram ? (
            <li>
              Telegram:{" "}
              <a href={`https://t.me/${SITE.telegram}`} target="_blank" rel="noreferrer">
                @{SITE.telegram}
              </a>
            </li>
          ) : null}
        </ul>

        <h2>Please note</h2>
        <p>
          We cannot give investment advice or recover lost funds. We will never ask for your seed
          phrase or private keys. If someone asks for them in our name, it is a scam.
        </p>

        <p className="legal-updated">Last updated: {SITE.updated}</p>
      </article>
    </main>
  );
}