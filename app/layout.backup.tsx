import { ensureArray } from '@/app/lib/safe';
import "./globals.css";

import Footer from './components/Footer';

import Header from './components/Header';

import { Analytics } from '@vercel/analytics/react';
import CookieConsent from './components/CookieConsent';
import defaultMetadata from './metadata';

import JsonLd from './components/JsonLd';export const metadata = defaultMetadata;
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Truvern',
  description: 'Vendor Trust Network | TPRM Platform',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
    <Header />{children}    <Footer />
    <Analytics />
    <CookieConsent />
    <JsonLd
  id="jsonld-org"
  data={{
    "@context": "https://schema.org",
    "@type": "Organization",
    "name": "Truvern",
    "url": "https://truvern.com",
    "logo": "https://truvern.com/favicon.svg",
    "sameAs": ["https://www.linkedin.com", "https://x.com"]
  }}
/>
    <JsonLd
  id="jsonld-website"
  data={{
    "@context": "https://schema.org",
    "@type": "WebSite",
    "name": "Truvern",
    "url": "https://truvern.com",
    "potentialAction": {
      "@type": "SearchAction",
      "target": "https://truvern.com/search?q={query}",
      "query-input": "required name=query"
    }
  }}
/>
</body>
    </html>
  )
}



