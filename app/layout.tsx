import type { Metadata } from "next";
import Script from "next/script";
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
        <Script id="microsoft-clarity" strategy="afterInteractive">
          {`(function(c,l,a,r,i,t,y){
              c[a]=c[a]||function(){(c[a].q=c[a].q||[]).push(arguments)};
              t=l.createElement(r);t.async=1;t.src="https://www.clarity.ms/tag/"+i;
              y=l.getElementsByTagName(r)[0];y.parentNode.insertBefore(t,y);
          })(window, document, "clarity", "script", "yo3syd0u0p");`}
        </Script>
        <Script
          async
          src="https://analytics.droply.digital/script.js"
          data-website-id="658809ad-5abd-4357-9858-bb12ec374311"
          strategy="afterInteractive"
        />
      </head>
      <body><AuroraBackground/><Header/>{children}<Footer/></body>
    </html>
  );
}