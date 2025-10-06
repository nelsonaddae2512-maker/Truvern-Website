
import React from 'react';
import Link from 'next/link';

export default function Dashboard(){
  return (
    <div className="p-8 space-y-4">
      <h1 className="text-3xl font-bold">Dashboard</h1>
      <div className="grid md:grid-cols-2 gap-4">
        <div className="border rounded p-4">
          <h2 className="text-xl font-semibold">Vendor workspace</h2>
          <p className="text-slate-600">Manage your Trust profile, answer controls, upload evidence.</p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Link className="h-9 px-3 rounded border" href="/vendor/upload">Upload evidence (URL)</Link>
            <Link className="h-9 px-3 rounded border" href="/vendor/upload-file">Upload evidence (File)</Link>
            <Link className="h-9 px-3 rounded border" href="/trust/embed">Badge embed</Link>
          </div>
        </div>
        <div className="border rounded p-4">
          <h2 className="text-xl font-semibold">Buyer workspace</h2>
          <p className="text-slate-600">Find pre‑assessed vendors. Request full security package.</p>
          <div className="mt-3 flex flex-wrap gap-2">
            <Link className="h-9 px-3 rounded border" href="/trust">Browse directory</Link>
            <Link className="h-9 px-3 rounded border" href="/contact">Contact a vendor</Link>
          </div>
        </div>
      </div>
    </div>
  );
}
