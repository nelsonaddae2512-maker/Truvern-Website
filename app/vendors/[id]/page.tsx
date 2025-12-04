// app/vendors/page.tsx
import Link from "next/link";
import { prisma } from "@/lib/prisma";

type VendorRow = {
  id: number;
  name: string;
  riskScore: number | null;
};

export const metadata = {
  title: "Vendors | Truvern",
  description: "Active vendors in your Truvern TPRM network.",
};

export default async function VendorsPage() {
  let vendors: VendorRow[] = [];
  let loadError: string | null = null;

  try {
    vendors = await prisma.vendor.findMany({
      orderBy: { name: "asc" },
      select: {
        id: true,
        name: true,
        riskScore: true,
      },
    });
  } catch (err: any) {
    // Log full error to Vercel runtime logs
    console.error("[/vendors] VENDORS_PAGE_ERROR:", err);
    loadError = err?.message ?? "Unknown error loading vendors";
  }

  // If something went wrong, render a friendly message instead of throwing.
  if (loadError) {
    return (
      <div className="mx-auto max-w-3xl px-4 py-16">
        <h1 className="text-2xl font-semibold mb-3">Vendors</h1>
        <div className="rounded-xl border border-red-500/40 bg-red-950/30 p-4">
          <p className="text-sm font-medium text-red-300">
            We couldn&apos;t load your vendors right now.
          </p>
          <p className="mt-2 text-xs text-red-200/80">
            Technical detail: {loadError}
          </p>
        </div>
        <p className="mt-6 text-sm text-slate-400">
          Try again in a moment, or return to the{" "}
          <Link href="/" className="text-emerald-400 hover:underline">
            home page
          </Link>
          .
        </p>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-4xl px-4 py-12 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Vendors</h1>
        <p className="mt-1 text-sm text-slate-400">
          Active vendors in your Truvern TPRM network.
        </p>
      </div>

      {vendors.length === 0 ? (
        <p className="text-sm text-slate-400">
          No vendors found yet. Seed some vendors in the database to get
          started.
        </p>
      ) : (
        <div className="overflow-hidden rounded-xl border border-slate-800 bg-slate-950/70">
          <table className="min-w-full text-sm">
            <thead className="bg-slate-900/70 text-xs uppercase tracking-wide text-slate-400">
              <tr>
                <th className="px-4 py-2 text-left">Name</th>
                <th className="px-4 py-2 text-right">Risk score</th>
              </tr>
            </thead>
            <tbody>
              {vendors.map((v) => (
                <tr
                  key={v.id}
                  className="border-t border-slate-800 hover:bg-slate-900/70"
                >
                  <td className="px-4 py-2">
                    <Link
                      href={`/vendors/${v.id}`}
                      className="text-emerald-400 hover:underline"
                    >
                      {v.name}
                    </Link>
                  </td>
                  <td className="px-4 py-2 text-right text-slate-200">
                    {v.riskScore ?? "—"}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
