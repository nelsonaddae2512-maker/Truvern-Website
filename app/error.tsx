"use client";

import { ensureArray } from '@/app/lib/safe';
export default function GlobalError({ error }: { error: Error & { digest?: string } }) {
  return (
    <html><body style={{padding:24}}>
      <h1>Something went wrong</h1>
      <p>{error?.message ?? "Unexpected error"}</p>
      <a href="/">Back home</a>
    </body></html>
  );
}

