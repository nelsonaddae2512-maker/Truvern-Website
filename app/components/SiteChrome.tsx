/** Phase120 – SiteChrome */
"use client";
import React from "react";
import Footer from "./Footer";

export default function SiteChrome({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen flex flex-col">
      <header className="border-b border-slate-800/60">
        <div className="container py-4 flex items-center justify-between">
          <a href="/" className="font-semibold tracking-tight text-xl">Truvern</a>
          <nav className="flex gap-5 text-sm">
            <a href="/trust-network">Trust</a>
            <a href="/vendors">Vendors</a>
            <a href="/pricing">Pricing</a>
            <a href="/contact">Contact</a>
          </nav>
        </div>
      </header>

      <main className="flex-1 container py-8">{children}</main>
      <Footer />
    </div>
  );
}
