import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Header from "@/components/Header";
import AuroraBackground from "@/components/AuroraBackground";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter", display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL("https://droply.digital"),
  title: { default: "Droply &mdash; Track what's dropping.", template: "%s &mdash; Droply" },
  description: "Discover upcoming crypto airdrops, snapshots, TGE and token claims in one place.",
  robots: { index: true, follow: true },
  openGraph: {
    type: "website",
    url: "https://droply.digital",
    siteName: "Droply",
    title: "Droply &mdash; Track what's dropping.",
    description: "Discover upcoming crypto airdrops, snapshots, TGE and token claims in one place.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Droply &mdash; Track what's dropping.",
    description: "Discover upcoming crypto airdrops, snapshots, TGE and token claims in one place.",
  },
};

export default function RootLayout({ children }: Readonly<{children: React.ReactNode}>) {
  return <html lang="en" className={inter.variable}><body><AuroraBackground/><Header/>{children}</body></html>;
}