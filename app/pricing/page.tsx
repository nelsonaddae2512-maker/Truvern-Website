import Link from "next/link";

export default function PricingPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <div className="mx-auto max-w-4xl px-4 py-16">
        <h1 className="text-3xl font-semibold mb-4">Pricing</h1>
        <p className="text-slate-300 mb-8">
          Truvern is designed to start small and grow with your third-party risk program.
        </p>

        <div className="grid gap-6 md:grid-cols-3">
          <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-6">
            <h2 className="text-lg font-semibold mb-2">Starter</h2>
            <p className="text-3xl font-bold mb-2">$0</p>
            <p className="text-xs text-slate-400 mb-4">per month</p>
            <ul className="space-y-1 text-sm text-slate-300">
              <li>• 1 organization</li>
              <li>• Up to 3 team members</li>
              <li>• Basic vendor registry</li>
              <li>• Sample board-level report</li>
            </ul>
          </div>

          <div className="rounded-xl border border-sky-600 bg-slate-900/80 p-6 shadow-lg">
            <h2 className="text-lg font-semibold mb-2">Growth</h2>
            <p className="text-3xl font-bold mb-2">$199</p>
            <p className="text-xs text-slate-400 mb-4">per month</p>
            <ul className="space-y-1 text-sm text-slate-300">
              <li>• Unlimited vendors</li>
              <li>• KPI stripe & risk scoring</li>
              <li>• Vendor portal access</li>
              <li>• Automated evidence reminders</li>
              <li>• Email support</li>
            </ul>
          </div>

          <div className="rounded-xl border border-slate-800 bg-slate-900/60 p-6">
            <h2 className="text-lg font-semibold mb-2">Enterprise</h2>
            <p className="text-3xl font-bold mb-2">Talk to us</p>
            <p className="text-xs text-slate-400 mb-4">custom pricing</p>
            <ul className="space-y-1 text-sm text-slate-300">
              <li>• Advanced reporting</li>
              <li>• SSO & custom roles</li>
              <li>• Dedicated onboarding</li>
              <li>• Vendor trust network insights</li>
            </ul>
          </div>
        </div>

        <div className="mt-10 flex flex-wrap gap-4">
          <Link
            href="/trust-network"
            className="inline-flex items-center rounded-md bg-sky-600 px-4 py-2 text-sm font-medium text-white hover:bg-sky-500"
          >
            View Trust Network
          </Link>
          <Link
            href="/contact"
            className="inline-flex items-center rounded-md border border-sky-500 px-4 py-2 text-sm font-medium text-sky-100 hover:bg-sky-600/10"
          >
            Talk to sales
          </Link>
        </div>
      </div>
    </main>
  );
}
