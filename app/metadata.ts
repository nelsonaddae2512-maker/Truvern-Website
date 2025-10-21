import type { Metadata } from "next";

export const site = {
  name: "Truvern",
  url: "https://truvern.com",
  description:
    "Truvern helps teams assess, compare, and continuously monitor third-party vendors.",
};

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: {
    default: site.name,
    template: "%s • Truvern",
  },
  description: site.description,
  keywords: [
    "third-party risk",
    "vendor security",
    "trust network",
    "TPRM",
    "security questionnaires",
  ],
  alternates: { canonical: site.url },
  openGraph: {
    type: "website",
    url: site.url,
    title: site.name,
    description: site.description,
    siteName: "Truvern",
    images: [{ url: "/opengraph-image.png" }],
  },
  twitter: {
    card: "summary_large_image",
    title: site.name,
    description: site.description,
    images: ["/opengraph-image.png"],
  },
  icons: {
    shortcut: "/favicon.svg",
    icon: "/favicon.svg",
  },
};
