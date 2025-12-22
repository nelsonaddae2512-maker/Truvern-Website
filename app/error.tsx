"use client";

import { useEffect } from "react";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  useEffect(() => {
    // Logs to browser console + terminal
    console.error(error);
  }, [error]);

  return (
    <main className="min-h-screen bg-slate-950 text-slate-50 flex items-center justify-center p-8">
      <div className="w-full max-w-2xl rounded-2xl border border-white/10 bg-slate-900/40 p-6">
        <h1 className="text-xl font-semibold">Truvern crashed on the client</h1>
        <p className="mt-2 text-sm text-slate-300/80">
          The actual error is below. Copy/paste it to patch the exact file.
        </p>

        <pre className="mt-4 overflow-auto rounded-xl bg-black/30 p-4 text-xs text-slate-200">
{String(error?.message || error)}
{error?.digest ? `\n\nDigest: ${error.digest}` : ""}
        </pre>

        <button
          onClick={() => reset()}
          className="mt-4 inline-flex items-center justify-center rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold hover:bg-indigo-500"
        >
          Try again
        </button>
      </div>
    </main>
  );
}
