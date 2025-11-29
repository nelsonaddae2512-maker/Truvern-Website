import Link from "next/link";

export default function ContactPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <div className="mx-auto max-w-3xl px-4 py-16">
        <h1 className="text-3xl font-semibold mb-4">Contact Truvern</h1>
        <p className="text-slate-300 mb-8">
          Have questions about the Truvern TPRM Trust Network, pricing, or onboarding?
          Send us a note and we&apos;ll get back to you.
        </p>

        <div className="space-y-4 text-sm text-slate-300">
          <p>
            <span className="font-semibold text-slate-100">Email:</span>{" "}
            <a href="mailto:support@truvern.com" className="text-sky-400 hover:underline">
              support@truvern.com
            </a>
          </p>
          <p>
            <span className="font-semibold text-slate-100">For security / risk teams:</span>{" "}
            mention that you&apos;re interested in the Truvern TPRM Trust Network, and
            include your company name, size, and key use-cases.
          </p>
        </div>

        <div className="mt-10">
          <Link
            href="/"
            className="inline-flex items-center rounded-md border border-sky-500 px-4 py-2 text-sm font-medium text-sky-100 hover:bg-sky-600/10"
          >
            ← Back to home
          </Link>
        </div>
      </div>
    </main>
  );
}
