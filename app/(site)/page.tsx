import React from "react";

export const dynamic = 'force-static'; // safe for SSG
export default function Page() {
  return (
    <div className="p-8 max-w-5xl mx-auto">
      <h1 className="text-2xl font-semibold">Welcome to Truvern</h1>
      <p className="mt-2">This (site) route group is building correctly.</p>
    </div>
  );
}