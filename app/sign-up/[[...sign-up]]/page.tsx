"use client";

import Link from "next/link";
import { SignUp } from "@clerk/nextjs";

export default function SignUpPage() {
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
              Get started with Truvern
            </h1>
            <p className="max-w-md text-sm text-slate-300">
              Create your first workspace, invite your team, and start recording
              vendor risk posture in a single shared network.
            </p>
            <ul className="space-y-2 text-xs text-slate-400">
              <li>• Start with a handful of critical vendors on the free tier.</li>
              <li>• Upgrade later for board-ready reporting and SSO.</li>
            </ul>
          </div>

          {/* Clerk sign-up widget */}
          <div className="flex justify-end">
            <div className="w-full max-w-sm">
              <SignUp
                routing="path"
                path="/sign-up"
                signInUrl="/sign-in"
                // afterSignUpUrl is already set globally, but this is fine as backup:
                afterSignUpUrl="/vendors"
              />
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
