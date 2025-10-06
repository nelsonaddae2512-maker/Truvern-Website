
'use client';
import React from 'react';

export default function EmbedHelp(){
  const [slug, setSlug] = React.useState('acme-labs');
  const code = `<a href="https://truvern.com/trust/${slug}" target="_blank" rel="noopener">
  <img src="https://truvern.com/api/trust/badge?slug=${slug}" alt="Trust badge for ${slug}" />
</a>`;
  return (
    <div className="max-w-3xl mx-auto p-8 space-y-3">
      <h1 className="text-3xl font-bold">Embed your Trust badge</h1>
      <input className="border rounded h-10 px-3" value={slug} onChange={e=>setSlug(e.target.value)} />
      <pre className="border rounded p-3 overflow-auto text-xs bg-slate-50">{code}</pre>
      <div className="mt-3">
        <img src={`/api/trust/badge?slug=${slug}`} alt="Preview" />
      </div>
    </div>
  );
}
