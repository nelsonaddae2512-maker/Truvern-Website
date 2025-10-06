
import React from "react";

async function getData(slug: string){
  const r = await fetch(`${process.env.NEXTAUTH_URL || ""}/api/trust/${slug}`, { cache: "no-store" });
  if(!r.ok) return null;
  return r.json();
}
export default async function TrustPage({ params }: { params: { slug: string } }){
  const data = await getData(params.slug);
  if(!data) return <div className="max-w-3xl mx-auto p-8">Not found</div>;
  const { vendor, trust, stats } = data;

  const pill = trust.level==="High" ? "bg-emerald-600"
           : trust.level==="Medium" ? "bg-amber-600"
           : "bg-rose-600";

  return (
    <div className="max-w-3xl mx-auto p-8 space-y-6">
      <div>
        <h1 className="text-3xl font-bold">{vendor.name}</h1>
        <div className="mt-2 flex items-center gap-2">
          <span className={`px-2 py-1 rounded text-white text-sm ${pill}`}>{trust.level} Trust</span>
          <span className="text-2xl font-bold">{trust.score}</span>
          <span className="text-xs text-slate-500">Updated {new Date(trust.updatedAt).toLocaleString()}</span>
        </div>
      </div>

      <div className="grid md:grid-cols-3 gap-3">
        <div className="border rounded p-3"><div className="text-xs text-slate-500">Controls answered</div><div className="text-2xl font-bold">{stats.answers}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-slate-500">Evidence approved</div><div className="text-2xl font-bold">{stats.evidenceApproved}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-slate-500">Evidence pending</div><div className="text-2xl font-bold">{stats.evidencePending}</div></div>
      </div>

      {!!stats.frameworks?.length && (
        <div className="border rounded p-4">
          <div className="text-sm font-semibold mb-2">Framework coverage</div>
          <div className="flex flex-wrap gap-2">
            {stats.frameworks.map((f:string)=> <span key={f} className="text-xs border rounded px-2 py-1 bg-slate-50">{f}</span>)}
          </div>
        </div>
      )}

      <div className="text-xs text-slate-500">
        Confidential details are withheld. This page shows a high-level trust summary supplied by the vendor and verified by evidence approvals.
      </div>

      <div className="flex flex-wrap gap-2">
        <a className="text-sm underline" href={`/api/trust/badge?slug=${vendor.slug}`}>Trust badge (SVG)</a>
        <a className="text-sm underline" href={`/contact?vendor=${vendor.slug}`}>Request full security package →</a>
      </div>
    </div>
  );
}
