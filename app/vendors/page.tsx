import Link from "next/link";
import prisma from "@/lib/prisma";

export const dynamic = "force-dynamic";

export default async function VendorsPage() {
  const vendors = await prisma.vendor.findMany({
    orderBy: { createdAt: "desc" },
  });

  return (
    <main className="max-w-5xl mx-auto px-6 py-10">
      <header className="mb-6">
        <h1 className="text-3xl font-semibold tracking-tight">Vendors</h1>
        <p className="mt-2 text-sm text-slate-400">
          Browse your vendors and open their evidence workspace.
        </p>
      </header>

      {vendors.length === 0 ? (
        <p className="text-slate-400">No vendors recorded yet.</p>
      ) : (
        <div className="overflow-x-auto rounded-xl border border-slate-800 bg-slate-950/40">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-900/60">
              <tr>
                <th className="px-4 py-3 text-left font-medium text-slate-300">
                  Name
                </th>
                <th className="px-4 py-3 text-left font-medium text-slate-300">
                  Risk score
                </th>
                <th className="px-4 py-3 text-left font-medium text-slate-300">
                  Created
                </th>
                <th className="px-4 py-3 text-right font-medium text-slate-300">
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              {vendors.map((vendor) => (
                <tr
                  key={vendor.id}
                  className="border-t border-slate-800 hover:bg-slate-900/60"
                >
                  <td className="px-4 py-3 text-slate-100">{vendor.name}</td>
                  <td className="px-4 py-3 text-slate-100">
                    {vendor.riskScore ?? "—"}
                  </td>
                  <td className="px-4 py-3 text-slate-400">
                    {new Date(vendor.createdAt).toLocaleDateString()}
                  </td>
                  <td className="px-4 py-3 text-right space-x-2">
                    <Link
                      href={`/vendors/${vendor.id}`}
                      className="inline-flex items-center rounded-md border border-slate-700 px-3 py-1 text-xs font-medium text-slate-100 hover:bg-slate-800"
                    >
                      Open
                    </Link>
                    <Link
                      href={`/vendors/${vendor.id}/evidence`}
                      className="inline-flex items-center rounded-md bg-emerald-600 px-3 py-1 text-xs font-medium text-white hover:bg-emerald-500"
                    >
                      Evidence
                    </Link>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </main>
  );
}
