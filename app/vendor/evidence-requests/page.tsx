// app/vendor/evidence-requests/page.tsx
import Link from "next/link";
import { redirect } from "next/navigation";
import prisma from "@/lib/prisma";
import { requireVendorPortalContext } from "@/lib/vendor-portal";
import EvidenceRequestStatusBadge from "@/components/evidence-request-status-badge";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

export default async function VendorEvidenceRequestsPage() {
  const res = await requireVendorPortalContext();
  if (!res.ok) redirect(res.redirectTo || "/vendor/not-linked");

  const { ctx } = res;
  const vendorId = (ctx.directLink as any).vendorId as number;
  const organizationId = (ctx.directLink as any).organizationId as number;

  const rows = await prisma.evidenceRequest.findMany({
    where: {
      vendorId,
      organizationId,
    } as any,
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    select: {
      id: true,
      label: true,
      description: true,
      kind: true,
      status: true,
      dueAt: true,
      updatedAt: true,
      createdAt: true,
      submittedAt: true,
      reviewedAt: true,
      reviewNote: true,
    } as any,
    take: 200,
  });

  const vendorName = (ctx.directVendor as any)?.name ?? "Vendor";

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold">Evidence Requests</h1>
          <p className="mt-1 text-sm text-white/70">
            Requests for <span className="text-white/90">{vendorName}</span>
          </p>
          {!ctx.vendorMatchesOrg && ctx.selectedClerkOrgId ? (
            <p className="mt-2 text-xs text-amber-200/80">
              Heads up: your selected org doesn’t match the vendor portal org. Access still works.
            </p>
          ) : null}
        </div>

        <div className="flex gap-2">
          <Link className={clsx("btn-glass")} href="/vendor">
            Back to Portal
          </Link>
          <Link className={clsx("btn-glass")} href="/vendors">
            Back to Org App
          </Link>
        </div>
      </div>

      <div className="mt-6 glass-soft rounded-2xl border border-white/10 overflow-hidden">
        <div className="px-5 py-4 border-b border-white/10 flex items-center justify-between">
          <div className="text-sm text-white/70">
            Showing <span className="text-white/90">{rows.length}</span> requests
          </div>
          <Link className="text-sm underline text-white/90" href="/vendor/debug">
            Debug
          </Link>
        </div>

        {rows.length === 0 ? (
          <div className="p-6 text-sm text-white/70">No evidence requests yet.</div>
        ) : (
          <div className="divide-y divide-white/10">
            {rows.map((r) => (
              <div key={r.id} className="p-5">
                <div className="flex items-start justify-between gap-4">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <div className="font-medium">{r.label || `Request #${r.id}`}</div>
                      <EvidenceRequestStatusBadge status={String(r.status)} />
                    </div>
                    {r.description ? <div className="mt-1 text-sm text-white/70">{r.description}</div> : null}
                  </div>

                  <div className="text-right text-xs text-white/60">
                    <div>Due: {fmtDate(r.dueAt as any)}</div>
                    <div>Updated: {fmtDate(r.updatedAt as any)}</div>
                  </div>
                </div>

                <div className="mt-4 flex flex-wrap gap-2">
                  {/* If you already have a vendor-facing detail route, wire it here */}
                  <Link className={clsx("btn-glass")} href={`/vendor/evidence-requests/${r.id}`}>
                    View
                  </Link>
                </div>

                {r.reviewNote ? (
                  <div className="mt-3 text-xs text-white/60">
                    Review note: <span className="text-white/80">{r.reviewNote}</span>
                  </div>
                ) : null}
              </div>
            ))}
          </div>
        )}
      </div>

      <p className="mt-10 text-xs text-white/50">
        Tip: If you need to submit evidence, open a request and upload the requested files.
      </p>
    </main>
  );
}
