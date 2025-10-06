
'use client';
import React from 'react';
import { signIn } from 'next-auth/react';
import { useSearchParams } from 'next/navigation';

export default function LoginPage(){
  const params = useSearchParams();
  const [email, setEmail] = React.useState('');
  const [sent, setSent] = React.useState(false);
  const error = params.get('error');

  async function onSubmit(e: React.FormEvent){
    e.preventDefault();
    const res = await signIn('email', { email, redirect: false });
    if(res?.ok){ setSent(true); } else { alert('Unable to send magic link'); }
  }

  return (
    <div className="max-w-sm mx-auto p-8">
      <h1 className="text-2xl font-bold mb-4">Sign in</h1>
      {!sent ? (
        <form onSubmit={onSubmit} className="space-y-3">
          <input className="border rounded w-full h-10 px-3" placeholder="you@company.com" type="email" value={email} onChange={e=>setEmail(e.target.value)} required />
          <button className="h-10 w-full rounded bg-slate-900 text-white">Email me a magic link</button>
          {error && <div className="text-sm text-rose-600">Login failed</div>}
        </form>
      ) : (
        <div className="text-slate-700">Check your inbox for a secure sign‑in link.</div>
      )}
      <div className="text-xs text-slate-500 mt-3">We’ll email a one‑time link. No passwords to remember.</div>
    </div>
  );
}
