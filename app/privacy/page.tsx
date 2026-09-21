import type { Metadata } from "next";
import Link from "next/link";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "Privacy Policy for Droply: what data the site handles when you visit, how it is used, and where to reach us with questions about your data.",
  alternates: { canonical: "/privacy" },
};

export default function PrivacyPage() {
  return (
    <main className="page container legal-page">
      <article className="article-card legal-card">
        <h1>Privacy Policy</h1>
        <p>
          This page explains what data Droply handles when you use droply.digital. We keep it to a
          minimum.
        </p>

        <h2>What we handle</h2>
        <ul>
          <li>
            There are no user accounts, and the site does not ask you to submit personal data.
          </li>
          <li>
            Favorites you save are stored in your own browser (local storage) on your device. We do
            not receive them.
          </li>
          <li>
            Like most websites, our hosting infrastructure may process technical data such as IP
            address, browser type and requested pages in server logs, for security and to keep the
            site running.
          </li>
        </ul>

        <h2>Analytics and cookies</h2>
        <p>
          At the moment Droply does not use advertising or analytics cookies. If we add analytics or
          any tracking, we will describe it on this page.
        </p>

        <h2>External links</h2>
        <p>
          Project pages link to third-party sites such as project websites, social networks,
          explorers and data sources. We do not control them, and their privacy practices are their
          own.
        </p>

        <h2>Contact</h2>
        <p>
          Questions about this policy: see the <Link href="/contact">contact page</Link>.
        </p>

        <p className="legal-updated">Last updated: {SITE.updated}</p>
      </article>
    </main>
  );
}