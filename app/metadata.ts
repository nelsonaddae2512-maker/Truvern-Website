import type { Metadata } from 'next';

export const defaultMetadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? 'https://truvern.com'),
  applicationName: 'Truvern',
  title: { default: 'Truvern', template: '%s — Truvern' },
  description:
    'Truvern is the Vendor Trust Network for modern TPRM — interactive assessments, evidence, and board-ready risk reporting.',
  authors: [{ name: 'Truvern' }],
  keywords: ['TPRM', 'third-party risk', 'vendor risk', 'security questionnaires', 'risk scoring', 'Truvern'],
  openGraph: {
    type: 'website',
    url: '/',
    siteName: 'Truvern',
    title: 'Truvern — Vendor Trust Network',
    description:
      'Assess vendors, share evidence, and report risk with confidence.',
    images: [{ url: '/opengraph-image.png', width: 1200, height: 630 }],
  },
  twitter: {
    card: 'summary_large_image',
    title: 'Truvern — Vendor Trust Network',
    description:
      'Assess vendors, share evidence, and report risk with confidence.',
    images: ['/opengraph-image.png'],
  },
  alternates: { canonical: '/' },
  icons: {
    icon: [{ url: '/favicon.ico' }, { url: '/favicon.svg' }],
    apple: [{ url: '/apple-touch-icon.png' }],
  },
};
export default defaultMetadata;