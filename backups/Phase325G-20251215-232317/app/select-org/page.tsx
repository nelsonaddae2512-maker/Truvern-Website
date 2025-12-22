import Link from "next/link";
import { SignedIn, SignedOut, OrganizationSwitcher } from "@clerk/nextjs";

export const dynamic = "force-dynamic";
export const revalidate = 0;

export default function SelectOrgPage() {
  return (
    <main className="min-h-[70vh]">
      <div className="mx-auto max-w-2xl px-6 py-12">
        <div className="rounded-2xl border border-white/10 bg-slate-950/40 p-6 shadow-sm">
          <h1 className="text-2xl font-semibold text-slate-50">Select an organization</h1>
          <p className="mt-2 text-sm text-slate-200/70">
            Truvern is organization-scoped. Choose the org you want to operate in.
          </p>

          <div className="mt-6">
            <SignedIn>
              <div className="rounded-xl border border-white/10 bg-black/20 p-4">
                <OrganizationSwitcher
                  appearance={{
                    elements: {
                      rootBox: "w-full",
                      organizationSwitcherTrigger:
                        "w-full justify-between rounded-lg border border-white/10 bg-slate-900/40 px-3 py-2 text-slate-50 hover:bg-slate-900/60",
                    },
                  }}
                />
              </div>

              <div className="mt-6 flex flex-wrap gap-3">
                <Link
                  href="/vendors"
                  className="rounded-lg bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-white"
                >
                  Continue to Vendors
                </Link>
                <Link
                  href="/"
                  className="rounded-lg border border-white/10 bg-slate-900/30 px-4 py-2 text-sm font-semibold text-slate-50 hover:bg-slate-900/50"
                >
                  Back to Home
                </Link>
              </div>
            </SignedIn>

            <SignedOut>
              <div className="mt-6 rounded-xl border border-white/10 bg-black/20 p-4">
                <p className="text-sm text-slate-200/70">
                  You are signed out. Please sign in first.
                </p>
                <div className="mt-4">
                  <Link
                    href="/sign-in"
                    className="rounded-lg bg-slate-50 px-4 py-2 text-sm font-semibold text-slate-900 hover:bg-white"
                  >
                    Go to Sign In
                  </Link>
                </div>
              </div>
            </SignedOut>
          </div>
        </div>
      </div>
    </main>
  );
}