
'use client';
import React from "react";
import Link from "next/link";
import { Logos } from "@/components/site/Logos";
import { Comparison } from "@/components/site/Comparison";
import { CTA } from "@/components/site/CTA";

export default function HomePage(){
  return (
    <div>
      <section className="px-6 pt-16 pb-12 md:pt-24 md:pb-16">
        <div className="max-w-6xl mx-auto grid md:grid-cols-2 gap-8 items-center">
          <div>
            <h1 className="text-4xl md:text-5xl font-extrabold leading-tight">Truvern — Verify once, share everywhere.</h1>
            <p className="mt-4 text-slate-600 text-lg">Publish a reusable trust profile with evidence. Buyers discover pre‑assessed vendors, instantly.</p>
            <div className="mt-6 flex flex-wrap gap-3">
              <Link href="/subscribe" className="h-11 px-5 rounded-xl bg-slate-900 text-white font-medium">Start Free</Link>
              <Link href="/trust" className="h-11 px-5 rounded-xl border font-medium">Browse Directory</Link>
            </div>
            <div className="mt-4 text-xs text-slate-500">Works with ISO 27001 · SOC 2 · NIST CSF · HIPAA</div>
          </div>
          <div className="border rounded-2xl p-4 shadow-sm">
            <div className="text-sm font-medium">Live Trust Profile (example)</div>
            <div className="mt-2 border rounded-xl p-4">
              <div className="flex items-center gap-2">
                <div className="w-10 h-10 rounded bg-slate-200" />
                <div>
                  <div className="font-semibold">Acme Labs</div>
                  <div className="text-xs text-slate-500">High Trust • 86</div>
                </div>
              </div>
              <div className="mt-3 grid grid-cols-3 gap-3 text-center">
                <div className="border rounded p-2"><div className="text-[11px] text-slate-500">Controls</div><div className="text-lg font-semibold">120</div></div>
                <div className="border rounded p-2"><div className="text-[11px] text-slate-500">Evidence</div><div className="text-lg font-semibold">34 ✓</div></div>
                <div className="border rounded p-2"><div className="text-[11px] text-slate-500">Frameworks</div><div className="text-lg font-semibold">ISO • NIST</div></div>
              </div>
              <div className="mt-3 text-xs text-slate-500">Shareable link · Embeddable badge · CISO override workflow</div>
            </div>
          </div>
        </div>
      </section>
      <Logos />
      <Comparison />
      <CTA />
    </div>
  );
}
