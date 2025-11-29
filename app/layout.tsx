import "./globals.css";
import type { Metadata } from "next";
import Navbar from "./components/Navbar";
import Footer from "./components/Footer";
import Head from "next/head";

export const metadata: Metadata = {
  metadataBase: new URL("https://truvern.com"),
  title: { default: "Truvern", template: "%s | Truvern" },
  description: "Truvern — Vendor trust network and TPRM platform.",
  openGraph: {
    title: "Truvern",
    description: "Vendor trust network and TPRM platform.",
    url: "https://truvern.com",
    images: ["/opengraph-image.png"],
    siteName: "Truvern",
  },
  icons: { icon: "/favicon.ico" },
  alternates: { canonical: "https://truvern.com" },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <Head>
        <meta property="og:image" content="/opengraph-image.png" />
        <link rel="canonical" href="https://truvern.com" />
      </Head>
      <body className="min-h-screen bg-gray-50 text-gray-900">
        <Navbar />
        {children}
        <Footer />
      </body>
    </html>
  );
}
