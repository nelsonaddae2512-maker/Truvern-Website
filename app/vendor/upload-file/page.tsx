
'use client';
import React from 'react';

export default function UploadFile(){
  const [vendorId, setVendorId] = React.useState('');
  const [questionId, setQuestionId] = React.useState('');
  const [file, setFile] = React.useState<File|null>(null);
  const [status, setStatus] = React.useState('');

  async function submit(e: React.FormEvent){
    e.preventDefault();
    if(!file) return;
    setStatus('Getting upload URL…');
    const r = await fetch('/api/evidence/presign', { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ filename: file.name, type: file.type || 'application/octet-stream' }) });
    const j = await r.json().catch(()=>null);
    if(!j?.url){ setStatus(j?.error || 'Presign failed'); return; }
    setStatus('Uploading to S3…');
    const up = await fetch(j.url, { method:'PUT', headers:{ 'content-type': file.type || 'application/octet-stream' }, body: file });
    if(!up.ok){ setStatus('S3 upload failed'); return; }
    setStatus('Finalizing…');
    const link = `s3://${process.env.NEXT_PUBLIC_APP_DOMAIN||'bucket'}/${j.key}`; // not public; store as URL in evidence table
    const save = await fetch('/api/evidence/upload', { method:'POST', headers:{'content-type':'application/json'}, body: JSON.stringify({ vendorId, questionId, url: link }) });
    const sj = await save.json().catch(()=>null);
    if(sj?.ok){ setStatus('Evidence stored. Awaiting review.'); } else { setStatus(sj?.error || 'Save failed'); }
  }

  return (
    <div className="max-w-lg mx-auto p-8">
      <h1 className="text-2xl font-bold mb-4">Upload evidence (File → S3)</h1>
      <form onSubmit={submit} className="space-y-3">
        <input className="border rounded w-full h-10 px-3" placeholder="Vendor ID" value={vendorId} onChange={e=>setVendorId(e.target.value)} required />
        <input className="border rounded w-full h-10 px-3" placeholder="Question ID" value={questionId} onChange={e=>setQuestionId(e.target.value)} required />
        <input className="border rounded w-full h-10 px-3 py-1" type="file" onChange={e=>setFile(e.target.files?.[0]||null)} required />
        <button className="h-10 w-full rounded bg-slate-900 text-white">Upload</button>
      </form>
      {status && <div className="text-sm mt-3">{status}</div>}
      <div className="text-xs text-slate-500 mt-3">This demo stores a non-public S3 URL in the evidence table. Serve files via signed GETs in production.</div>
    </div>
  );
}
