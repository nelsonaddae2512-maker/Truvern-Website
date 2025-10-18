
'use client';
import React from 'react';

export default function EvidenceUpload(){
  const [vendorId, setVendorId] = React.useState('');
  const [questionId, setQuestionId] = React.useState('');
  const [url, setUrl] = React.useState('');
  const [note, setNote] = React.useState('');
  const [msg, setMsg] = React.useState<string|null>(null);

  async function submit(e: React.FormEvent){
    e.preventDefault();
    setMsg(null);
    const r = await fetch('/api/evidence/upload', { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ vendorId, questionId, url, note }) });
    const j = await r.json().catch(()=>null);
    if(j?.ok){ setMsg('Evidence submitted for review.'); setUrl(''); setNote(''); }
    else setMsg(j?.error || 'Failed to upload evidence');
  }

  return (
    <div className="max-w-lg mx-auto p-8">
      <h1 className="text-2xl font-bold mb-4">Upload evidence (URL)</h1>
      <form onSubmit={submit} className="space-y-3">
        <input className="border rounded w-full h-10 px-3" placeholder="Vendor ID" value={vendorId} onChange={e=>setVendorId(e.target.value)} required />
        <input className="border rounded w-full h-10 px-3" placeholder="Question ID" value={questionId} onChange={e=>setQuestionId(e.target.value)} required />
        <input className="border rounded w-full h-10 px-3" placeholder="Link to evidence (e.g., GDrive, S3)" value={url} onChange={e=>setUrl(e.target.value)} required />
        <textarea className="border rounded w-full h-24 px-3 py-2" placeholder="Note (optional)" value={note} onChange={e=>setNote(e.target.value)} />
        <button className="h-10 w-full rounded bg-slate-900 text-white">Submit</button>
      </form>
      {msg && <div className="text-sm mt-3">{msg}</div>}
      <div className="text-xs text-slate-500 mt-3">Files are out-of-scope for this demo. Use secure URLs (S3 pre-signed, GDrive, etc.).</div>
    </div>
  );
}


