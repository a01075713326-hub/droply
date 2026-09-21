import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Airdrop Calendar",
  description: "Snapshots, TGE dates, claims and airdrop events in one calendar.",
  robots: { index: false, follow: true },
};

export default function CalendarLayout({ children }: { children: React.ReactNode }) {
  return <>{children}</>;
}