// app/page.tsx
import Link from "next/link";
import { IntegrityHeroStrip } from "@/components/IntegrityHeroStrip";

export default function HomePage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      {/* Hero */}
      <section className="relative overflow-hidden border-b border-slate-800/70">
        <div className="truvern-hero-bg pointer-events-none absolute inset-0 opacity-70" />
        <div className="relative mx-auto flex max-w-6xl flex-col gap-10 px-4 pb-16 pt-16 md:flex-row md:items-center md:pt-20">
          {/* Left column */}
          <div className="flex-1 space-y-6">
            {/* Integrity strip + live posture pill */}
            <div className="flex flex-col gap-3">
              <IntegrityHeroStrip />

              <div className="inline-flex items-center gap-2 rounded-full border border-slate-700/70 bg-slate-950/80 px-3 py-1 text-[11px] text-slate-300 backdrop-blur">
                <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
                <span className="font-semibold tracking-[0.2em] text-sky-300 uppercase">
                  Live posture
                </span>
                <span className="text-slate-400">
                  Vendors · Evidence · Board report
                </span>
              </div>
            </div>

            <div className="space-y-4">
              <h1 className="text-balance text-3xl font-semibold leading-tight tracking-tight sm:text-4xl md:text-5xl">
                One place to{" "}
                <span className="bg-gradient-to-r from-sky-400 via-emerald-400 to-sky-300 bg-clip-text text-transparent">
                  see, prove, and share
                </span>{" "}
                third-party risk posture.
              </h1>
              <p className="max-w-xl text-sm text-slate-200 sm:text-base">
                Truvern connects vendor assessments, evidence, and board-level
                reporting into a single live trust network. No spreadsheet
                rodeos. No one-off questionnaires. Just defensible answers you
                can share.
              </p>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <Link
                href="/trust-network"
                className="inline-flex items-center justify-center rounded-full bg-sky-500 px-5 py-2.5 text-sm font-medium text-slate-950 shadow-sm shadow-sky-500/40 transition hover:bg-sky-400"
              >
                View Trust Network
              </Link>
              <Link
                href="/vendors"
                className="inline-flex items-center justify-center rounded-full border border-slate-600/80 bg-slate-950/70 px-5 py-2.5 text-sm font-medium text-slate-100 hover:border-sky-400"
              >
                Open Vendor workspace
              </Link>
              <Link
                href="/pricing"
                className="inline-flex items-center justify-center rounded-full px-3 py-1.5 text-xs font-medium text-slate-300 hover:text-sky-300"
              >
                See plans &amp; pricing →
              </Link>
            </div>

            <div className="grid gap-3 text-xs text-slate-200 sm:grid-cols-3 sm:text-sm">
              <ValuePill label="Normalize SIG, CAIQ, and custom questionnaires" />
              <ValuePill label="Board-ready risk summaries in one click" />
              <ValuePill label="Vendor portal they actually want to use" />
            </div>
          </div>

          {/* Right column mock dashboard */}
          <div className="flex flex-1 items-center justify-center md:justify-end">
            <div className="relative w-full max-w-md">
              <div className="pointer-events-none absolute -inset-0.5 -z-10 rounded-3xl bg-gradient-to-tr from-sky-500/40 via-emerald-400/30 to-fuchsia-500/25 opacity-90 blur-xl" />
              <div className="overflow-hidden rounded-3xl border border-slate-800/80 bg-slate-950/95 shadow-xl shadow-slate-950/80">
                <DashboardMock />
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Feature row */}
      <section className="border-b border-slate-800 bg-slate-950/95">
        <div className="mx-auto grid max-w-6xl gap-6 px-4 py-10 md:grid-cols-3">
          <FeatureCard
            title="Live vendor health"
            body="Roll up complex assessment data and evidence into a single, explainable health score per vendor."
          />
          <FeatureCard
            title="Board-ready out of the box"
            body="Defensible risk summaries and trends that the board can actually read—with detail one click away."
          />
          <FeatureCard
            title="Shareable trust network"
            body="Give vendors a single, secure workspace to answer once, share everywhere, and track remediation."
          />
        </div>
      </section>

      {/* CTA band */}
      <section className="bg-slate-950">
        <div className="mx-auto flex max-w-6xl flex-col items-center gap-4 px-4 py-10 text-center md:flex-row md:justify-between md:text-left">
          <div className="space-y-1">
            <h2 className="text-lg font-semibold text-slate-50">
              Ready to make third-party risk a first-class signal?
            </h2>
            <p className="max-w-xl text-sm text-slate-300">
              Start with a handful of critical vendors on the free tier, then
              grow into Pro when you&apos;re ready to standardize board
              reporting.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-3">
            <Link
              href="/pricing"
              className="inline-flex items-center justify-center rounded-full bg-sky-500 px-5 py-2.5 text-sm font-medium text-slate-950 hover:bg-sky-400"
            >
              Explore pricing
            </Link>
            <Link
              href="/reports/board"
              className="inline-flex items-center justify-center rounded-full border border-slate-600 bg-slate-950 px-5 py-2.5 text-sm font-medium text-slate-100 hover:border-sky-400"
            >
              Preview board report
            </Link>
          </div>
        </div>
      </section>
    </main>
  );
}

function ValuePill({ label }: { label: string }) {
  return (
    <div className="inline-flex items-center gap-2 rounded-full border border-slate-700/80 bg-slate-950/80 px-3 py-1">
      <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
      <span>{label}</span>
    </div>
  );
}

function FeatureCard({ title, body }: { title: string; body: string }) {
  return (
    <div className="space-y-2 rounded-2xl border border-slate-800/80 bg-slate-950/90 p-4">
      <h3 className="text-sm font-semibold text-slate-50">{title}</h3>
      <p className="text-xs text-slate-300 sm:text-sm">{body}</p>
    </div>
  );
}

function DashboardMock() {
  const vendors = [
    { name: "Cloud billing provider", score: 86, status: "Healthy" },
    { name: "Payroll + HR", score: 73, status: "Watch" },
    { name: "Marketing automation", score: 64, status: "Review" },
  ];

  return (
    <div className="text-xs text-slate-200">
      <div className="flex items-center justify-between border-b border-slate-800 px-4 py-3">
        <div>
          <p className="text-[11px] text-slate-400">Truvern · Overview</p>
          <p className="text-sm font-semibold text-slate-50">
            Vendor risk snapshot
          </p>
        </div>
        <span className="rounded-full bg-emerald-500/15 px-2 py-0.5 text-[10px] font-medium text-emerald-300">
          Live sync
        </span>
      </div>

      <div className="grid gap-3 border-b border-slate-800 px-4 py-4 sm:grid-cols-3">
        <MiniStat label="Vendors" value="24" />
        <MiniStat label="Assessed" value="18" />
        <MiniStat label="High-risk" value="3" tone="danger" />
      </div>

      <div className="space-y-1.5 px-4 py-3">
        {vendors.map((v) => (
          <div
            key={v.name}
            className="flex items-center justify-between rounded-xl border border-slate-800 bg-slate-950 px-3 py-2"
          >
            <div className="max-w-[60%]">
              <p className="truncate text-[11px] font-medium text-slate-100">
                {v.name}
              </p>
              <p className="text-[10px] text-slate-400">
                CAIQ · Evidence attached
              </p>
            </div>
            <div className="text-right">
              <div className="text-sm font-semibold text-sky-300">
                {v.score}
              </div>
              <div className="text-[10px] text-emerald-300">{v.status}</div>
            </div>
          </div>
        ))}
      </div>

      <div className="flex items-center justify-between border-t border-slate-800 px-4 py-2.5 text-[10px] text-slate-400">
        <span>Export board summary in one click</span>
        <span className="rounded-full border border-slate-700 px-2 py-0.5 text-[9px] text-slate-300">
          SIG · CAIQ · Custom
        </span>
      </div>
    </div>
  );
}

function MiniStat({
  label,
  value,
  tone,
}: {
  label: string;
  value: string;
  tone?: "danger";
}) {
  const color = tone === "danger" ? "text-rose-300" : "text-sky-300";
  return (
    <div className="space-y-1 rounded-2xl border border-slate-800 bg-slate-950 px-3 py-2">
      <p className="text-[10px] tracking-wide text-slate-400">{label}</p>
      <p className={`text-lg font-semibold ${color}`}>{value}</p>
    </div>
  );
}
