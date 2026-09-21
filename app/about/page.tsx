import type { Metadata } from "next";
import Link from "next/link";
import { SITE } from "@/lib/site";

export const metadata: Metadata = {
  title: "About the Airdrop Tracker: Data and Verification",
  description: "What Droply is, where its airdrop data comes from and how projects are checked.",
  alternates: { canonical: "/about" },
};

export default function AboutPage() {
  return (
    <main className="page container legal-page">
      <article className="article-card legal-card">
        <h1>About Droply</h1>
        <p>
          Droply is a crypto airdrop tracker. It collects airdrop and points campaigns from public
          sources and puts the main facts in one place: status, chain, estimated cost to farm,
          deadlines and step-by-step tasks.
        </p>

        <h2>Where the data comes from</h2>
        <p>
          Project data is gathered automatically from public sources, currently CryptoRank,
          Airdrops.io and AirdropAlert. Each project page names its source and links back to it.
          Data can change or lag behind the source, so always confirm important details on the
          official channels of the project.
        </p>

        <h2>How projects are checked</h2>
        <p>
          For many projects we run automated checks: whether the official website is reachable,
          whether social links are confirmed by the official site, and whether a contract address
          and a public audit exist. The result is shown as a risk level together with the full list
          of rules, so you can see why a project got its score. The score is a screening aid, not a
          verdict, and a low score does not mean a project is safe.
        </p>

        <h2>What is reviewed by hand</h2>
        <p>
          Selected projects also have our own overview, risks and notes. Those sections are marked
          Our take and show the date of the last review. Everything else on a project page is
          compiled automatically.
        </p>

        <h2>Links and independence</h2>
        <p>
          If we use affiliate or referral links, they are labelled as sponsored and they do not
          change how a project is scored.
        </p>

        <h2>Corrections</h2>
        <p>
          Found a mistake, or represent a project and want something fixed? Use the{" "}
          <Link href="/contact">contact page</Link>.
        </p>

        <p className="legal-updated">Last updated: {SITE.updated}</p>
      </article>
    </main>
  );
}