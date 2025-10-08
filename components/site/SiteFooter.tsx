
import React from 'react';
import Link from 'next/link';
import { useI18n } from "../../lib/i18n";
import { LanguageSwitcher } from '@/components/site/LanguageSwitcher';

export function SiteFooter(){
  const { t } = useI18n();
  return (
    <footer className="mt-16 border-t">
      <div className="max-w-6xl mx-auto px-6 py-10 grid md:grid-cols-4 gap-6 text-sm">
        <div>
          <div className="font-semibold">Truvern</div>
          <div className="text-slate-600 mt-2">{t('footer.tagline')}</div>
        </div>
        <div>
          <div className="font-semibold">Product</div>
          <ul className="mt-2 space-y-1">
            <li><Link href="/features">Features</Link></li>
            <li><Link href="/pricing">Pricing</Link></li>
            <li><Link href="/trust">Directory</Link></li>
          </ul>
        </div>
        <div>
          <div className="font-semibold">Company</div>
          <ul className="mt-2 space-y-1">
            <li><a href="/legal/privacy">Privacy</a></li>
            <li><a href="/legal/terms">Terms</a></li>
            <li><a href="/contact">Contact</a></li>
          </ul>
        </div>
        <div>
          <div className="font-semibold">Get started</div>
          <div className="mt-2"><a className="h-10 px-4 rounded-xl bg-slate-900 text-white inline-flex items-center" href="/subscribe">Start Free</a></div>
        </div>
      </div>
      <div className="flex items-center justify-between text-xs text-slate-500 px-6 py-4 border-t"><span>Â© {new Date().getFullYear()} Truvern</span><LanguageSwitcher /></div>
    </footer>
  );
}
