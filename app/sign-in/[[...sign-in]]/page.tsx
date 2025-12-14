"use client";

import Link from "next/link";
import { SignIn } from "@clerk/nextjs";

export default function SignInPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50">
      <section className="mx-auto flex max-w-5xl flex-col gap-8 px-4 pb-16 pt-20">
        {/* Breadcrumb */}
        <Link
          href="/"
          className="text-xs text-slate-400 hover:text-sky-300 inline-flex items-center gap-1"
        >
          ← Back to home
        </Link>

        <div className="grid gap-10 md:grid-cols-[minmax(0,1.1fr)_minmax(0,1fr)]">
          {/* Marketing copy */}
          <div className="space-y-4">
            <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
              Sign in to Truvern
            </h1>
            <p className="max-w-md text-sm text-slate-300">
              Access your vendor workspace, assessments, and board-ready risk
              reports in a single live trust network.
            </p>
            <ul className="space-y-2 text-xs text-slate-400">
              <li>• Resume vendor onboarding or assessment reviews.</li>
              <li>• Keep evidence and board snapshots in sync automatically.</li>
              <li>• SSO (Okta, Azure AD, Google Workspace) coming soon.</li>
            </ul>
          </div>

          {/* Clerk sign-in widget */}
          <div className="flex justify-end">
            <div className="w-full max-w-sm">
              <SignIn routing="path" path="/sign-in" />
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
