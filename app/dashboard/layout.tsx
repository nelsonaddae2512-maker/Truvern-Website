import type { Metadata } from "next";
import React from "react";

export const metadata: Metadata = {
  title: {
    default: "Truvern dashboard",
    template: "%s | Truvern dashboard",
  },
  description:
    "Truvern dashboard for TPRM assessments, evidence and vendor trust network views.",
};

export default function DashboardLayout(props: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-slate-950 text-slate-50">
      <header className="border-b border-slate-800 bg-slate-900/70 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-3">
          <div className="text-sm font-semibold tracking-tight">
            Truvern dashboard
          </div>
          <nav className="flex gap-4 text-xs opacity-80">
            <span>/trust-network</span>
            <span>/reports/board</span>
            <span>/vendors</span>
          </nav>
        </div>
      </header>

      <main className="mx-auto flex max-w-6xl gap-6 px-6 py-6">
        <aside className="hidden w-56 flex-shrink-0 rounded-lg border border-slate-800 bg-slate-900/60 p-4 text-xs md:block">
          <div className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-slate-400">
            Sections
          </div>
          <ul className="space-y-1 text-slate-300">
            <li>Overview</li>
            <li className="font-semibold text-sky-300">Evidence</li>
            <li>Vendors</li>
            <li>Assessments</li>
            <li>Usage & billing</li>
          </ul>
        </aside>

        <section className="flex-1 rounded-lg border border-slate-800 bg-slate-900/60 p-5">
          {props.children}
        </section>
      </main>
    </div>
  );
}
