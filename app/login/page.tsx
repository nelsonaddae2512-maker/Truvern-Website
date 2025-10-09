"use client";
import React, { Suspense } from "react";
import { useSearchParams } from "next/navigation";

function LoginInner(){
  const sp = useSearchParams();
  const emailPrefill = sp.get("email") || "";
  return (
    <main className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-semibold mb-4">Login</h1>
      <form method="post" action="/api/auth/signin/email" className="space-y-4">
        <input
          name="email"
          type="email"
          required
          defaultValue={emailPrefill}
          placeholder="you@company.com"
          className="w-full border rounded p-3"
        />
        <button className="px-4 py-2 rounded bg-black text-white">Send magic link</button>
      </form>
    </main>
  );
}

export default function Page(){
  return (
    <Suspense fallback={<div className="p-6">Loading…</div>}>
      <LoginInner />
    </Suspense>
  );
}