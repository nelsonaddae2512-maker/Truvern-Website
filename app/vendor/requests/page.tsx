// app/vendor/requests/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireVendorPortalContext } from "@/lib/vendor-portal";

export const dynamic = "force-dynamic";
export const revalidate = 0;

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

export default async function VendorRequestsPage() {
  const ctx = await requireVendorPortalContext();

  const rows = await prisma.evidenceRequest.findMany({
    where: { organizationId: ctx.organizationId, vendorId: ctx.vendorId } as any,
    orderBy: [{ dueAt: "asc" }, { updatedAt: "desc" }],
    take: 200,
    select: {
      id: true,
      label: true,
      kind: true,
      status: true,
      dueAt: true,
      updatedAt: true,
    },
  });

  return (
    <main className="container-page py-10">
      <div className="flex items-end justify-between gap-4">
        <div>
          <h1 className="text-3xl font-semibold">Evidence Requests</h1>
          <p className="text-white/70 mt-2">Open each request to upload evidence and see review notes.</p>
        </div>
        <Link className="btn-glass" href="/vendor">
          Dashboard
        </Link>
      </div>

      <div className="glass-soft mt-8 overflow-hidden">
        <div className="px-5 py-3 border-b border-white/10 text-sm text-white/70">
          {rows.length} request(s)
        </div>

        <div className="divide-y divide-white/10">
          {rows.map((r) => (
            <Link
              key={r.id}
              href={`/vendor/requests/${r.id}`}
              className="block px-5 py-4 hover:bg-white/5 transition"
            >
              <div className="flex items-center justify-between gap-4">
                <div className="min-w-0">
                  <div className="font-medium truncate">{r.label}</div>
                  <div className="text-xs text-white/60 mt-1">
                    Due: {fmtDate(r.dueAt)} • Updated: {fmtDate(r.updatedAt)}
                  </div>
                </div>
                <div className="text-xs px-2 py-1 rounded-full border border-white/15 text-white/80">
                  {r.status}
                </div>
              </div>
            </Link>
          ))}

          {rows.length === 0 && (
            <div className="px-5 py-10 text-white/70">
              No evidence requests assigned to your vendor yet.
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
