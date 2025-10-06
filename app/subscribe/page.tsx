
'use client';
import React from 'react';

function Plan({title,descr,tier}:{title:string;descr:string;tier:'starter'|'pro'|'enterprise'}){
  const [loading, setLoading] = React.useState(false);
  async function buy(){
    setLoading(true);
    const r = await fetch('/api/stripe/checkout', { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ tier }) });
    const j = await r.json().catch(()=>null);
    setLoading(false);
    if(j?.url) window.location.href = j.url; else alert(j?.error || 'Unable to start checkout');
  }
  return (
    <div className="border rounded-2xl p-6 flex flex-col justify-between">
      <div>
        <div className="text-lg font-semibold">{title}</div>
        <div className="text-slate-600 text-sm mt-1">{descr}</div>
      </div>
      <button onClick={buy} disabled={loading} className="mt-6 h-10 px-4 rounded-xl bg-slate-900 text-white">{loading?'Loading…':'Choose ' + title}</button>
    </div>
  );
}

export default function SubscribePage(){
  async function portal(){
    const r = await fetch('/api/stripe/portal', { method:'POST' });
    const j = await r.json().catch(()=>null);
    if(j?.url) window.location.href = j.url; else alert(j?.error || 'No billing portal available');
  }
  return (
    <div className="px-6 py-12 md:py-16 max-w-6xl mx-auto space-y-8">
      <h1 className="text-3xl md:text-4xl font-bold">Choose your plan</h1>
      <div className="grid md:grid-cols-3 gap-6">
        <Plan title="Starter" descr="3 seats, publish Trust Profile, Board Report PDF" tier="starter" />
        <Plan title="Pro" descr="Unlimited seats, remediation, evidence queue, integrations" tier="pro" />
        <Plan title="Enterprise" descr="SSO/SAML, API, custom branding, support SLAs" tier="enterprise" />
      </div>
      <div><button onClick={portal} className="h-10 px-4 rounded-xl border">Open billing portal</button></div>
    </div>
  );
}
