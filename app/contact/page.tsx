// app/contact/page.tsx

import Link from "next/link";

export const metadata = {
  title: "Contact – Truvern",
  description:
    "Get in touch with the Truvern team for product questions, partnerships, or support.",
};

export default function ContactPage() {
  return (
    <main className="relative max-w-3xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      {/* Soft background glows */}
      <div className="pointer-events-none absolute inset-x-0 -top-32 -z-10 h-64 bg-[radial-gradient(circle_at_top,_rgba(45,212,191,0.25),transparent_60%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-64 bg-[radial-gradient(circle_at_bottom,_rgba(56,189,248,0.20),transparent_60%)]" />

      {/* Accent line */}
      <div className="h-px w-full bg-gradient-to-r from-emerald-400/80 via-cyan-400/70 to-violet-500/70 mb-6" />

      {/* Header */}
      <section className="space-y-4 mb-8">
        <div className="inline-flex items-center gap-2 rounded-full bg-slate-900/70 border border-emerald-500/30 px-3 py-1">
          <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
          <span className="text-[10px] font-semibold tracking-[0.2em] text-emerald-300 uppercase">
            Truvern contact
          </span>
        </div>

        <div>
          <h1 className="text-3xl lg:text-4xl font-semibold text-slate-50 tracking-tight">
            Talk to the Truvern team
          </h1>
          <p className="mt-3 max-w-xl text-sm lg:text-base text-slate-300">
            Whether you&apos;re exploring Truvern, running a live vendor risk
            program, or just curious about what we&apos;re building, we&apos;d
            love to hear from you.
          </p>
        </div>
      </section>

      {/* Contact options */}
      <section className="space-y-6">
        {/* Primary card */}
        <div className="rounded-3xl border border-slate-800 bg-slate-950/70 p-6 shadow-lg shadow-black/40">
          <h2 className="text-sm font-semibold text-slate-100 mb-2">
            Message the team
          </h2>
          <p className="text-xs text-slate-400 mb-4">
            Share a bit about what you&apos;re looking for and how we can help.
            We typically respond within one business day.
          </p>

          {/* This form is visual only for now; handle however you prefer later */}
          <form
            className="space-y-4"
            action="mailto:hello@example.com"
            method="post"
            encType="text/plain"
          >
            <div className="space-y-1">
              <label
                htmlFor="name"
                className="block text-xs font-medium text-slate-300"
              >
                Name
              </label>
              <input
                id="name"
                name="name"
                type="text"
                className="w-full rounded-xl border border-slate-700 bg-slate-900/80 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/60 focus:border-emerald-400"
                placeholder="How should we address you?"
              />
            </div>

            <div className="space-y-1">
              <label
                htmlFor="email"
                className="block text-xs font-medium text-slate-300"
              >
                Work email
              </label>
              <input
                id="email"
                name="email"
                type="email"
                className="w-full rounded-xl border border-slate-700 bg-slate-900/80 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/60 focus:border-emerald-400"
                placeholder="you@company.com"
              />
            </div>

            <div className="space-y-1">
              <label
                htmlFor="message"
                className="block text-xs font-medium text-slate-300"
              >
                How can we help?
              </label>
              <textarea
                id="message"
                name="message"
                rows={4}
                className="w-full rounded-xl border border-slate-700 bg-slate-900/80 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-emerald-500/60 focus:border-emerald-400 resize-none"
                placeholder="Share a quick overview of your vendor risk use case, timelines, or questions."
              />
            </div>

            <button
              type="submit"
              className="inline-flex items-center gap-2 rounded-full bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 shadow-md shadow-emerald-500/40 hover:bg-emerald-400 transition"
            >
              <span>Send message</span>
              <span>↗</span>
            </button>
          </form>
        </div>

        {/* Secondary cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
            <h3 className="text-xs font-semibold text-slate-100 mb-1">
              Partnerships &amp; integrations
            </h3>
            <p className="text-xs text-slate-400 mb-2">
              Building adjacent tools, data feeds, or integrations that might
              pair well with Truvern?
            </p>
            <p className="text-xs text-slate-300">
              Reach out at{" "}
              <a
                href="mailto:partners@example.com"
                className="text-emerald-300 hover:text-emerald-200"
              >
                partners@example.com
              </a>
              .
            </p>
          </div>

          <div className="rounded-2xl border border-slate-800 bg-slate-950/60 p-4">
            <h3 className="text-xs font-semibold text-slate-100 mb-1">
              Support
            </h3>
            <p className="text-xs text-slate-400 mb-2">
              Already using Truvern and need help with a vendor, assessment, or
              billing?
            </p>
            <p className="text-xs text-slate-300">
              Email{" "}
              <a
                href="mailto:support@example.com"
                className="text-emerald-300 hover:text-emerald-200"
              >
                support@example.com
              </a>{" "}
              and include your organization name so we can route you quickly.
            </p>
          </div>
        </div>

        <p className="text-[11px] text-slate-500 mt-4">
          Prefer not to email yet? You can always explore the{" "}
          <Link
            href="/trust-network"
            className="text-emerald-300 hover:text-emerald-200"
          >
            Truvern Trust Network
          </Link>{" "}
          or{" "}
          <Link
            href="/pricing"
            className="text-emerald-300 hover:text-emerald-200"
          >
            pricing
          </Link>{" "}
          first and come back when you&apos;re ready.
        </p>
      </section>
    </main>
  );
}
