'use client';


import { ensureArray } from '@/app/lib/safe';
import { useEffect, useState } from 'react';

export default function CookieConsent() {
  const KEY = 'tvn_cookie_consent_v1';
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (typeof window !== 'undefined' && !localStorage.getItem(KEY)) setOpen(true);
  }, []);

  if (!open) return null;

  return (
    <div className="fixed inset-x-0 bottom-0 z-50">
      <div className="mx-auto max-w-7xl m-4 rounded-md border bg-white p-4 shadow">
        <p className="text-sm">
          We use cookies for essential site functionality and analytics. See our{" "}
          <a href="/legal/privacy" className="underline">Privacy Policy</a>.
        </p>
        <div className="mt-3 flex gap-2">
          <button
            onClick={() => { localStorage.setItem(KEY, 'accepted'); setOpen(false); }}
            className="rounded-md bg-blue-600 px-3 py-1.5 text-white text-sm"
          >Accept</button>
          <button
            onClick={() => setOpen(false)}
            className="rounded-md border px-3 py-1.5 text-sm"
          >Close</button>
        </div>
      </div>
    </div>
  );
}

