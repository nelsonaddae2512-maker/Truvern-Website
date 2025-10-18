"use client";
export default function GlobalError({ error }: { error: Error & { digest?: string } }){
  return (
    <html><body>
      <main className="px-6 py-20 text-center">
        <h1 className="text-3xl font-semibold mb-3">Something went wrong</h1>
        <p className="text-neutral-600">Please reload. If this persists, contact support.</p>
      </main>
    </body></html>
  );
}

