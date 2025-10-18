
'use client';
import React from 'react';
export default function Contact(){
  const [sent, setSent] = React.useState(false);
  async function submit(e: React.FormEvent){
    e.preventDefault();
    setSent(true);
  }
  return (
    <div className="max-w-lg mx-auto p-8">
      <h1 className="text-3xl font-bold mb-4">Contact us</h1>
      {!sent ? (
        <form onSubmit={submit} className="space-y-3">
          <input className="border rounded w-full h-10 px-3" placeholder="Your name" required />
          <input className="border rounded w-full h-10 px-3" type="email" placeholder="Email" required />
          <textarea className="border rounded w-full h-28 px-3 py-2" placeholder="Message" required />
          <button className="h-10 w-full rounded bg-slate-900 text-white">Send</button>
        </form>
      ) : (
        <div className="text-green-700">Thanks! Weâ€™ll get back to you soon.</div>
      )}
    </div>
  );
}


