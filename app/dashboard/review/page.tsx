
'use client';
import React from 'react';

type Row = { id:string; vendorId:string; questionId:string; url:string; reviewerNote?:string|null; status:'approved'|'rejected'|'pending'; createdAt:string; vendor?:{name?:string} };

export default function ReviewQueue(){
  const [rows, setRows] = React.useState<Row[]>([]);
  const [loading, setLoading] = React.useState(true);
  const [note, setNote] = React.useState<Record<string,string>>({});
  const [error, setError] = React.useState<string|null>(null);

  async function load(){
    setLoading(true); setError(null);
    const r = await fetch('/api/evidence/list').catch(()=>null);
    if(!r){ setError('Network error'); setLoading(false); return; }
    const j = await r.json().catch(()=>null);
    if(!j){ setError('Invalid response'); setLoading(false); return; }
    setRows(Array.isArray(j.items)? j.items : []);
    setLoading(false);
  }

  React.useEffect(()=>{ load(); },[]);

  async function act(id:string, status:'approved'|'rejected'){
    const r = await fetch('/api/evidence/review', {
      method:'POST', headers:{'content-type':'application/json'},
      body: JSON.stringify({ id, status, note: note[id]||'' })
    });
    const j = await r.json().catch(()=>null);
    if(j?.ok){ setRows(prev => prev.filter(x => x.id !== id)); }
    else alert(j?.error || 'Failed');
  }

  async function view(row: Row){
    // If it's an s3:// URL we need a signed GET. Expect shape s3://<bucket>/<key> or key known at upload time.
    if(row.url.startsWith('s3://')){
      const key = row.url.replace(/^s3:\/\//,'').split('/').slice(1).join('/');
      const r = await fetch(`/api/evidence/get-url?key=${encodeURIComponent(key)}`);
      const j = await r.json().catch(()=>null);
      if(j?.url) window.open(j.url, '_blank');
      else alert(j?.error || 'Unable to sign URL');
    }else{
      window.open(row.url, '_blank');
    }
  }

  return (
    <div className="p-8 max-w-6xl mx-auto space-y-4">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold">Evidence review</h1>
        <button onClick={load} className="h-9 px-3 rounded border">Refresh</button>
      </div>
      {loading && <div className="text-sm text-slate-600">Loading…</div>}
      {error && <div className="text-sm text-red-600">{error}</div>}
      {!loading && rows.length===0 && <div className="text-sm text-slate-600">No items pending review.</div>}
      {rows.length>0 && (
        <div className="overflow-x-auto border rounded">
          <table className="min-w-[880px] w-full text-sm">
            <thead className="bg-slate-50">
              <tr>
                <th className="p-2 text-left">Vendor</th>
                <th className="p-2 text-left">Question</th>
                <th className="p-2 text-left">Submitted</th>
                <th className="p-2 text-left">Status</th>
                <th className="p-2 text-left">Note</th>
                <th className="p-2 text-left">Actions</th>
              </tr>
            </thead>
            <tbody>
              {rows.map(r => (
                <tr key={r.id} className="border-t">
                  <td className="p-2">{r.vendor?.name||r.vendorId}</td>
                  <td className="p-2">{r.questionId}</td>
                  <td className="p-2">{new Date(r.createdAt).toLocaleString()}</td>
                  <td className="p-2 capitalize">{r.status}</td>
                  <td className="p-2 w-[320px]">
                    <input className="border rounded w-full h-9 px-2" placeholder="Reviewer note" value={note[r.id]||''}
                      onChange={e=>setNote(p=>({ ...p, [r.id]: e.target.value }))}/>
                  </td>
                  <td className="p-2">
                    <div className="flex gap-2">
                      <button onClick={()=>view(r)} className="h-8 px-2 rounded border">View</button>
                      <button onClick={()=>act(r.id,'approved')} className="h-8 px-2 rounded bg-emerald-600 text-white">Approve</button>
                      <button onClick={()=>act(r.id,'rejected')} className="h-8 px-2 rounded bg-red-600 text-white">Reject</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <div className="text-xs text-slate-500">
        Your list is scoped to your organizations only. Evidence with private storage is fetched via short‑lived signed URLs.
      </div>
    </div>
  );
}
