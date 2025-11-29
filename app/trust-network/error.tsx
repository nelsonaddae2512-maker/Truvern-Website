'use client';

export default function Error({ error }: { error: Error & { digest?: string } }) {
  return (
    <main style={{ padding: 24 }}>
      <h2>We hit a snag.</h2>
      <p>{error?.message ?? 'Unknown error'}</p>
      <p>
        <a href='/'>Go back to Home</a> | <a href='/reports/board/preview'>Open Board Report</a>
      </p>
    </main>
  );
}
