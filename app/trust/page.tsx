
'use client';
import React from 'react';
import Link from 'next/link';

type Item = { name: string; slug: string; trustScore: number | null; trustLevel: string | null; updatedAt: string; frameworks: string[] };

export default function TrustDirectory(){
  const [items, setItems] = React.useState<Item[]>([]);
  const [q, setQ] = React.useState('');
  const [fw, setFw] = React.useState('');

  async function load(){
    const params = new URLSearchParams(); if(q) params.set('q', q); if(fw) params.set('framework', fw);
    const r = await fetch('/api/trust/list?' + params.toString()); if(r.ok){ const j = await r.json(); setItems(j.vendors || []); }
  }
  React.useEffect(()=>{ load(); }, []);

  function onSubmit(e: React.FormEvent){ e.preventDefault(); load(); }

  return (
    <div className="max-w-5xl mx-auto p-8 space-y-4">
      <h1 className="text-3xl font-bold">Global Vendor Trust Directory</h1>
      <form onSubmit={onSubmit} className="flex flex-wrap gap-2 items-center">
        <input className="border rounded h-10 px-3" placeholder="Search vendorâ€¦" value={q} onChange={e=>setQ(e.target.value)} />
        <input className="border rounded h-10 px-3" placeholder="Filter framework (e.g., ISO 27001)" value={fw} onChange={e=>setFw(e.target.value)} />
        <button className="h-10 px-3 rounded bg-slate-900 text-white">Search</button>
      </form>

      <div className="grid md:grid-cols-2 gap-3">
        {items.map(it => {
          const pill = it.trustLevel==='High' ? 'bg-emerald-600' : it.trustLevel==='Medium' ? 'bg-amber-600' : 'bg-rose-600';
          return (
            <div key={it.slug} className="border rounded p-4 flex flex-col gap-2">
              <div className="flex items-center justify-between">
                <Link href={`/trust/${it.slug}`} className="font-semibold underline">{it.name}</Link>
                <span className={`px-2 py-1 rounded text-white text-xs ${pill}`}>{it.trustLevel || 'â€”'}</span>
              </div>
              <div className="text-sm">Score: <span className="font-semibold">{it.trustScore ?? 'â€”'}</span></div>
              {!!it.frameworks?.length && <div className="flex flex-wrap gap-2">{it.frameworks.map(f=><span key={f} className="text-xs border rounded px-2 py-0.5 bg-slate-50">{f}</span>)}</div>}
              <div className="text-[11px] text-slate-500">Updated {new Date(it.updatedAt).toLocaleString()}</div>
            </div>
          );
        })}
        {!items.length && <div className="text-slate-600">No vendors found.</div>}
      </div>
    </div>
  );
}


