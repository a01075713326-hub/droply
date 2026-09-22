import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import Header from "@/components/Header";
import AuroraBackground from "@/components/AuroraBackground";
import Footer from "@/components/Footer";

const inter = Inter({ subsets: ["latin"], variable: "--font-inter", display: "swap" });

export const metadata: Metadata = {
  metadataBase: new URL("https://droply.digital"),
  title: { default: "Droply \u2014 Track what's dropping.", template: "%s \u2014 Droply" },
  description: "Discover upcoming crypto airdrops, snapshots, TGE and token claims in one place.",
  robots: { index: true, follow: true },
  openGraph: {
    type: "website",
    siteName: "Droply",
    title: "Droply \u2014 Track what's dropping.",
    description: "Discover upcoming crypto airdrops, snapshots, TGE and token claims in one place.",
  },
  twitter: {
    card: "summary_large_image",
    title: "Droply \u2014 Track what's dropping.",
    description: "Discover upcoming crypto airdrops, snapshots, TGE and token claims in one place.",
  },
};

export default function RootLayout({ children }: Readonly<{children: React.ReactNode}>) {
  return (
    <html lang="en" className={inter.variable}>
      <head>
        <script type="module" src="https://static.cloudflareinsights.com/beacon.min.js" data-cf-beacon='{"token": "4154b45fac604535bd8729e76bf00677"}'></script>
      </head>
      <body><AuroraBackground/><Header/>{children}<Footer/></body>
    </html>
  );
}