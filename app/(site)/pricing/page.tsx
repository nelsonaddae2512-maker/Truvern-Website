
import React from 'react';
import { headers } from 'next/headers';
import { detectCountry, currencyFor, formatPrice } from '@/lib/currency';

export const dynamic = 'force-dynamic';

export default async function Pricing(){
  const country = detectCountry(await headers());
  const cur = currencyFor(country);
  const starter = formatPrice(99, cur);
  const pro = formatPrice(399, cur);
  return (
    <div className="p-8 max-w-6xl mx-auto space-y-8">
      <h1 className="text-3xl md:text-4xl font-bold">Simple, global pricing</h1>
      <div className="grid md:grid-cols-3 gap-6">
        <div className="border rounded-2xl p-6">
          <div className="text-lg font-semibold">Starter</div>
          <div className="text-3xl font-extrabold mt-2">{starter}<span className="text-base font-normal">/mo</span></div>
          <div className="text-sm text-slate-600 mt-1">Up to 3 seats. Publish Trust profile.</div>
          <a href="/subscribe" className="mt-5 h-10 w-full rounded-xl bg-slate-900 text-white inline-flex items-center justify-center">Choose Starter</a>
        </div>
        <div className="border rounded-2xl p-6 ring-2 ring-emerald-500">
          <div className="text-lg font-semibold">Pro</div>
          <div className="text-3xl font-extrabold mt-2">{pro}<span className="text-base font-normal">/mo</span></div>
          <div className="text-sm text-slate-600 mt-1">Unlimited seats. Remediation & evidence.</div>
          <a href="/subscribe" className="mt-5 h-10 w-full rounded-xl bg-emerald-600 text-white inline-flex items-center justify-center">Choose Pro</a>
        </div>
        <div className="border rounded-2xl p-6">
          <div className="text-lg font-semibold">Enterprise</div>
          <div className="text-3xl font-extrabold mt-2">Custom</div>
          <div className="text-sm text-slate-600 mt-1">SSO/SAML, API, SLA, BAAs.</div>
          <a href="/contact" className="mt-5 h-10 w-full rounded-xl border inline-flex items-center justify-center">Talk to sales</a>
        </div>
      </div>
      <div className="text-xs text-slate-500">Detected country: {country} • Currency: {cur.code}</div>
    </div>
  );
}
