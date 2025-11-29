import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Evidence workspace",
  description:
    "Central workspace for Truvern evidence uploads, mappings, and board-ready documentation.",
  alternates: {
    canonical: "/dashboard/evidence",
  },
  openGraph: {
    title: "Truvern evidence workspace",
    description:
      "Manage vendor evidence, attach documents to controls, and prepare board-ready reports.",
    url: "https://truvern.com/dashboard/evidence",
    images: ["/opengraph-image.png"],
  },
};

export default function EvidenceDashboardPage() {
  return (
    <div className="space-y-6">
      <header className="border-b border-slate-800 pb-4">
        <h1 className="text-xl font-semibold tracking-tight">
          Evidence workspace
        </h1>
        <p className="mt-1 text-sm text-slate-300">
          Review uploaded artifacts, map them to controls, and confirm what is
          ready for board reporting.
        </p>
      </header>

      <section className="grid gap-4 md:grid-cols-3">
        <div className="rounded-lg border border-slate-800 bg-slate-950/60 p-4 text-sm">
          <h2 className="mb-2 text-[13px] font-semibold tracking-wide text-slate-300">
            Incoming evidence
          </h2>
          <p className="text-xs text-slate-400">
            Placeholder list for new vendor uploads, SOC reports, policies and
            other files awaiting review.
          </p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-950/60 p-4 text-sm">
          <h2 className="mb-2 text-[13px] font-semibold tracking-wide text-slate-300">
            Control mappings
          </h2>
          <p className="text-xs text-slate-400">
            Future view for mapping evidence to specific Truvern control
            domains and risk themes.
          </p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-950/60 p-4 text-sm">
          <h2 className="mb-2 text-[13px] font-semibold tracking-wide text-slate-300">
            Board-ready bundle
          </h2>
          <p className="text-xs text-slate-400">
            This panel will surface the subset of evidence referenced by the
            /reports/board view once wiring is complete.
          </p>
        </div>
      </section>
    </div>
  );
}
