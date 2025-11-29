// app/about/page.tsx

import type { Metadata } from "next";

export const dynamic = "force-static";   // prevents node lambda creation

export const metadata: Metadata = {
  title: "About Truvern",
  description:
    "Learn about Truvern, the vendor trust network and intelligent third-party risk platform.",
};

export default function AboutPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="mx-auto max-w-4xl px-4 py-20 space-y-6">
        <h1 className="text-4xl font-bold tracking-tight">About Truvern</h1>
        <p className="text-slate-300 text-lg">
          Truvern is the next-generation TPRM platform providing vendor trust,
          assessments, automated insights, and board-ready reporting.
        </p>

        <p className="text-slate-400">
          This static placeholder ensures build stability while we finalize the
          full About page content.
        </p>

        <div className="mt-8 flex gap-4">
          <a
            href="/trust-network"
            className="px-4 py-2 rounded-lg border border-emerald-600 text-emerald-200"
          >
            Trust Network
          </a>
          <a
            href="/vendors"
            className="px-4 py-2 rounded-lg border border-slate-700 text-slate-200"
          >
            Vendors
          </a>
        </div>
      </section>
    </main>
  );
}
