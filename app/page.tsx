import Link from "next/link";

export const dynamic = "force-static";

export default function HomePage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="max-w-5xl mx-auto px-4 py-16 space-y-10">
        <div className="space-y-4">
          <p className="text-xs uppercase tracking-[0.2em] text-sky-400">
            Truvern Â· Third-Party Risk Network
          </p>
          <h1 className="text-3xl md:text-4xl font-semibold leading-tight">
            One place to see, prove, and share{" "}
            <span className="text-sky-400">third-party risk posture</span>.
          </h1>
          <p className="text-sm md:text-base text-slate-300 max-w-2xl">
            Truvern connects your vendors, evidence, and board-level reporting
            in a single, always-current trust network. No spreadsheet rodeos,
            no one-off questionnaires, just clear answers you can defend.
          </p>
        </div>

        <div className="flex flex-wrap gap-3">
          <Link
            href="/trust-network"
            className="inline-flex items-center rounded-md bg-sky-500 px-4 py-2 text-sm font-medium text-slate-950 hover:bg-sky-400 transition"
          >
            View Trust Network
          </Link>
          <Link
            href="/vendors"
            className="inline-flex items-center rounded-md border border-slate-700 px-4 py-2 text-sm font-medium text-slate-100 hover:bg-slate-900 transition"
          >
            Open Vendor Workspace
          </Link>
        </div>

        <div className="grid gap-4 md:grid-cols-3 text-xs md:text-sm text-slate-300">
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="font-medium text-slate-100">Live vendor risk scores</p>
            <p>
              Normalize SIG, CAIQ, custom questionnaires, and evidence into a
              single health score per vendor.
            </p>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="font-medium text-slate-100">Board-ready reports</p>
            <p>
              Export concise, defensible views for the board without exposing
              all the operational detail behind the scenes.
            </p>
          </div>
          <div className="rounded-lg border border-slate-800 bg-slate-900/40 p-4 space-y-1">
            <p className="font-medium text-slate-100">Vendor-friendly portal</p>
            <p>
              Give vendors one link where they can answer once, share everywhere,
              and track their own remediation.
            </p>
          </div>
        </div>
      </section>
    </main>
  );
}
