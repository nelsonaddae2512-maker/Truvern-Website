'use client';


import { ensureArray } from '@/app/lib/safe';
export default function GlobalError({ error, reset }: { error: Error, reset: () => void }) {
  return (
    <html>
      <body style={{padding:'2rem', maxWidth:900, margin:'0 auto', lineHeight:1.6}}>
        <h2>We hit a snag.</h2>
        <p>{error?.message || 'An unexpected error occurred.'}</p>
        <p>
          <a href="/" style={{textDecoration:'underline'}}>Go back to Home</a>
          {' '}|{' '}
          <a href="/reports/board" style={{textDecoration:'underline'}}>Open Board Report</a>
        </p>
        <button onClick={() => reset()}>Try again</button>
      </body>
    </html>
  );
}
