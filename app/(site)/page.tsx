import React from "react";
// Keep this simple; no 'use client' or browser-only APIs
export const dynamic = 'force-static';
export default function Page() {
  return (
    <div className="p-8 max-w-5xl mx-auto">
      <h1 className="text-2xl font-semibold">Welcome to Truvern</h1>
      <p className="mt-2">This root landing page under the (site) route group is building correctly.</p>
    </div>
  );
}