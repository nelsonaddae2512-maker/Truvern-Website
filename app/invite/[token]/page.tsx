
'use client';
import React from 'react';

export default function InviteAccept({ params }: { params: { token: string } }){
  const [msg, setMsg] = React.useState('Processing invite…');
  React.useEffect(()=>{
    (async()=>{
      const r = await fetch('/api/invite/' + params.token);
      if(r.ok){ setMsg('Invite accepted! Check your email for a magic link to sign in.'); }
      else{ setMsg('Invite is invalid or expired.'); }
    })();
  }, [params.token]);
  return (
    <div className="max-w-lg mx-auto p-8">
      <h1 className="text-2xl font-bold mb-3">Invitation</h1>
      <div>{msg}</div>
    </div>
  );
}
