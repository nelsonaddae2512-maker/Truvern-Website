"use client";
export default function GlobalError({ error }: { error: Error }) {
  return (
    <html><body>
      <main className="min-h-[60vh] grid place-items-center p-8 text-center">
        <div>
          <h1 className="text-3xl font-bold">Something went wrong</h1>
          <p className="mt-2 text-gray-600">{error?.message ?? "Unknown error"}</p>
          <a className="mt-6 inline-block rounded-lg border px-4 py-2 hover:bg-gray-50" href="/">Back home</a>
        </div>
      </main>
    </body></html>
  );
}
