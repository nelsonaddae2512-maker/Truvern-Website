// app/pricing/page.tsx
import Link from "next/link";

export const metadata = {
  title: "Pricing – Truvern",
  description:
    "Simple pricing for security teams using the Truvern TPRM Trust Network, from free pilots to enterprise rollouts.",
};

const features = {
  starter: [
    "Up to 3 vendors",
    "Single organization",
    "Vendor assessments & evidence",
    "Board report preview (watermarked)",
    "Email support",
  ],
  pro: [
    "Up to 75 vendors",
    "Unlimited assessments & evidence",
    "Board-ready report export (PDF & CSV)",
    "Custom risk scoring model",
    "Role-based access (Owner / Admin / Analyst)",
    "Priority email support",
  ],
  enterprise: [
    "Unlimited vendors & assessments",
    "Multiple organizations / business units",
    "Custom data residency & retention",
    "SSO / SAML & advanced RBAC",
    "Dedicated customer success",
    "Quarterly executive review",
  ],
};

export default function PricingPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <div className="mx-auto flex max-w-6xl flex-col gap-10 px-4 pb-24 pt-16 lg:pt-20">
        {/* Hero */}
        <header className="text-center">
          <p className="text-xs font-semibold uppercase tracking-[0.22em] text-emerald-300">
            Pricing
          </p>
          <h1 className="mt-3 text-3xl font-semibold tracking-tight sm:text-4xl md:text-5xl">
            Start small, grow into board-ready third-party risk.
          </h1>
          <p className="mx-auto mt-4 max-w-3xl text-sm leading-relaxed text-slate-300">
            Truvern scales with you—from validating a handful of critical
            vendors to running a live risk network across your entire ecosystem.
            Upgrade directly from your workspace when you&apos;re ready.
          </p>
        </header>

        {/* Plans */}
        <section className="grid gap-6 md:grid-cols-3">
          {/* Starter */}
          <article className="glass-soft flex flex-col rounded-3xl p-6 text-sm shadow-sm shadow-slate-950/60">
            <div className="mb-4 flex items-center justify-between gap-2">
              <div>
                <h2 className="text-base font-semibold tracking-tight">
                  Starter
                </h2>
                <p className="mt-1 text-xs text-slate-400">
                  Best for security teams piloting Truvern.
                </p>
              </div>
              <span className="rounded-full bg-slate-800 px-2 py-[2px] text-[10px] font-medium text-slate-200">
                Get started free
              </span>
            </div>

            <div className="mb-5">
              <div className="flex items-baseline gap-1">
                <span className="text-3xl font-semibold">$0</span>
                <span className="text-xs text-slate-400">forever</span>
              </div>
            </div>

            <ul className="mb-6 space-y-2 text-xs text-slate-200">
              {features.starter.map((f) => (
                <li key={f} className="flex items-start gap-2">
                  <span className="mt-[5px] inline-flex h-1.5 w-1.5 rounded-full bg-emerald-400" />
                  <span>{f}</span>
                </li>
              ))}
            </ul>

            <div className="mt-auto">
              <Link
                href="/sign-up"
                className="btn-primary w-full items-center justify-center text-xs"
              >
                Start with free vendors
              </Link>
              <p className="mt-2 text-[11px] text-slate-500">
                No credit card required. Upgrade to Pro from inside your vendor
                workspace at any time.
              </p>
            </div>
          </article>

          {/* Pro */}
          <article className="glass-soft flex flex-col rounded-3xl border border-emerald-500/60 bg-slate-900/80 p-6 text-sm shadow-lg shadow-emerald-500/25">
            <div className="mb-4 flex items-center justify-between gap-2">
              <div>
                <h2 className="text-base font-semibold tracking-tight">Pro</h2>
                <p className="mt-1 text-xs text-slate-300">
                  For teams that need board-ready reporting.
                </p>
              </div>
              <span className="rounded-full bg-emerald-500/15 px-2 py-[2px] text-[10px] font-medium text-emerald-200">
                Most popular
              </span>
            </div>

            <div className="mb-5">
              <div className="flex items-baseline gap-1">
                <span className="text-3xl font-semibold">$249</span>
                <span className="text-xs text-slate-400">per month</span>
              </div>
              <p className="mt-2 text-[11px] text-slate-400">
                Billed monthly via Stripe. Cancel anytime.
              </p>
            </div>

            <ul className="mb-6 space-y-2 text-xs text-slate-200">
              {features.pro.map((f) => (
                <li key={f} className="flex items-start gap-2">
                  <span className="mt-[5px] inline-flex h-1.5 w-1.5 rounded-full bg-emerald-400" />
                  <span>{f}</span>
                </li>
              ))}
            </ul>

            <div className="mt-auto">
              <Link
                href="/vendor-space/billing"
                className="btn-primary w-full items-center justify-center text-xs"
              >
                Talk to us about Pro
              </Link>
              <p className="mt-2 text-[11px] text-slate-500">
                Upgrades happen securely through the billing section of your
                Truvern workspace. Permissions and limits update instantly.
              </p>
            </div>
          </article>

          {/* Enterprise */}
          <article className="glass-soft flex flex-col rounded-3xl p-6 text-sm shadow-sm shadow-slate-950/60">
            <div className="mb-4 flex items-center justify-between gap-2">
              <div>
                <h2 className="text-base font-semibold tracking-tight">
                  Enterprise
                </h2>
                <p className="mt-1 text-xs text-slate-300">
                  For regulated, multi-entity organizations.
                </p>
              </div>
              <span className="rounded-full bg-slate-800 px-2 py-[2px] text-[10px] font-medium text-slate-200">
                Custom
              </span>
            </div>

            <div className="mb-5">
              <p className="text-2xl font-semibold">Let&apos;s talk</p>
              <p className="mt-2 text-[11px] text-slate-400">
                Annual or multi-year agreements. Invoicing available.
              </p>
            </div>

            <ul className="mb-6 space-y-2 text-xs text-slate-200">
              {features.enterprise.map((f) => (
                <li key={f} className="flex items-start gap-2">
                  <span className="mt-[5px] inline-flex h-1.5 w-1.5 rounded-full bg-emerald-400" />
                  <span>{f}</span>
                </li>
              ))}
            </ul>

            <div className="mt-auto">
              <Link
                href="/contact"
                className="btn-glass w-full items-center justify-center text-xs"
              >
                Contact sales
              </Link>
              <p className="mt-2 text-[11px] text-slate-500">
                We&apos;ll work with your security and procurement teams on
                deployment model, data residency, and legal review.
              </p>
            </div>
          </article>
        </section>

        {/* Billing + rollout info */}
        <section className="glass-soft mt-4 space-y-6 rounded-3xl p-6 text-sm text-slate-200">
          <div className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-400">
                How billing & access works
              </p>
              <h2 className="mt-2 text-base font-semibold tracking-tight">
                Designed for real security teams, not one-off pilots.
              </h2>
            </div>
            <Link
              href="/contact"
              className="btn-glass items-center justify-center text-xs"
            >
              Talk to us about rollout
            </Link>
          </div>

          <div className="grid gap-4 text-xs md:grid-cols-3">
            <div className="glass-soft rounded-2xl p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                1. Start in Starter
              </p>
              <p className="mt-2 text-slate-300">
                Spin up a workspace, connect a few critical vendors, and trial
                the Truvern workflow with real assessments and evidence.
              </p>
            </div>
            <div className="glass-soft rounded-2xl p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                2. Upgrade in-app
              </p>
              <p className="mt-2 text-slate-300">
                When you&apos;re ready, upgrade to Pro directly from the billing
                page via Stripe. Billing owners control plan changes and
                receipts.
              </p>
            </div>
            <div className="glass-soft rounded-2xl p-4">
              <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
                3. Scale to Enterprise
              </p>
              <p className="mt-2 text-slate-300">
                Need multiple workspaces, SSO, or data residency controls? Our
                team will design a rollout with you and handle contracting and
                onboarding.
              </p>
            </div>
          </div>
        </section>

        {/* Final CTA */}
        <section className="glass-soft mt-4 rounded-3xl p-5 text-center text-xs text-slate-300">
          <p>
            Need a different deployment model or want to mirror data from an
            existing GRC / TPRM stack?{" "}
            <Link
              href="/contact"
              className="font-medium text-emerald-300 hover:text-emerald-200 hover:underline"
            >
              Let&apos;s design a Truvern rollout together.
            </Link>
          </p>
        </section>
      </div>
    </main>
  );
}
