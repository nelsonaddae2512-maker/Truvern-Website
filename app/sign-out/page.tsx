"use client";

import Link from "next/link";
import { SignOutButton } from "@clerk/nextjs";

export default function SignOutPage() {
  return (
    <main className="container-page py-10">
      <div className="mx-auto max-w-lg rounded-2xl border border-white/10 bg-slate-950/40 p-6">
        <h1 className="text-2xl font-semibold text-white">Sign out</h1>
        <p className="mt-2 text-sm text-slate-300">
          If you're stuck in a weird session state, use this to fully sign out.
        </p>

        <div className="mt-5 flex flex-wrap items-center gap-2">
          <SignOutButton redirectUrl="/">
            <button className="btn-primary">Sign out now</button>
          </SignOutButton>

          <Link className="btn-secondary" href="/">
            Back home
          </Link>
        </div>
      </div>
    </main>
  );
}
