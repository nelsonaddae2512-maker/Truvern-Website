
'use client';
import React from 'react';
import Link from 'next/link';
import { AuthButtons } from '@/components/site/AuthButtons';
import { useI18n } from "../../lib/i18n";
import { LanguageSwitcher } from '@/components/site/LanguageSwitcher';
import { Logo } from '@/components/site/Logo';

export function SiteNav(){
  const { t } = useI18n();
  const [open, setOpen] = React.useState(false);
  return (
    <header className="sticky top-0 z-40 bg-white/80 backdrop-blur border-b">
      <div className="max-w-6xl mx-auto px-6 h-14 flex items-center justify-between">
        <Link href="/" className="flex items-center gap-2 font-semibold">
          <Logo />
          Truvern
        </Link>
        <nav className="hidden md:flex items-center gap-6 text-sm">
          <Link href="/features">{t('nav.features')}</Link>
          <Link href="/vendors">{t('nav.vendors')}</Link>
          <Link href="/buyers">{t('nav.buyers')}</Link>
          <Link href="/pricing">{t('nav.pricing')}</Link>
          <Link href="/trust-network">{t('nav.trust')}</Link>
          <Link href="/trust" className="text-slate-500">{t('nav.directory')}</Link>
          <Link href="/subscribe" className="h-9 px-3 rounded border">{t('nav.subscribe')}</Link>
          <AuthButtons />
        </nav><LanguageSwitcher />
        <button className="md:hidden" onClick={()=>setOpen(!open)} aria-label="Menu">☰</button>
      </div>
      {open && (
        <div className="md:hidden px-6 pb-3 flex flex-col gap-2 text-sm">
          <Link href="/features">{t('nav.features')}</Link>
          <Link href="/vendors">{t('nav.vendors')}</Link>
          <Link href="/buyers">{t('nav.buyers')}</Link>
          <Link href="/pricing">{t('nav.pricing')}</Link>
          <Link href="/trust-network">{t('nav.trust')}</Link>
          <Link href="/trust">Directory</Link>
          <Link href="/subscribe" className="h-9 px-3 rounded border inline-flex items-center justify-center w-28">Subscribe</Link>
          <AuthButtons />
        </div>
      )}
    </header>
  );
}
