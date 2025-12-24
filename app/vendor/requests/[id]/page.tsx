// app/vendor/requests/[id]/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import { requireVendorPortalContext } from "@/lib/vendor-portal";
import VendorEvidenceUpload from "@/components/vendor/vendor-evidence-upload.client";

export const dynamic = "force-dynamic";
export const revalidate = 0;

function fmtTime(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

type ParamsPromise = Promise<{ id: string }>;
type Props = { params: ParamsPromise };

export default async function VendorRequestDetailPage({ params }: Props) {
  const ctx = await requireVendorPortalContext();
  const { id } = await params;
  const requestId = Number(id);

  const req = await prisma.evidenceRequest.findFirst({
    where: { id: requestId, organizationId: ctx.organizationId, vendorId: ctx.vendorId } as any,
    select: {
      id: true,
      label: true,
      description: true,
      status: true,
      dueAt: true,
      updatedAt: true,
      reviewNote: true,
      iterations: {
        orderBy: [{ id: "desc" }],
        take: 10,
        select: {
          id: true,
          createdAt: true,
          submittedAt: true,
          status: true,
          note: true,
        },
      },
    },
  });

  if (!req) {
    return (
      <main className="container-page py-16">
        <h1 className="text-2xl font-semibold">Request not found</h1>
        <div className="mt-6">
          <Link className="btn-glass" href="/vendor/requests">
            Back
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0">
          <Link className="text-white/70 hover:text-white" href="/vendor/requests">
            ← Evidence Requests
          </Link>
          <h1 className="text-3xl font-semibold mt-2 truncate">{req.label}</h1>

          {req.description && <p className="text-white/70 mt-2 max-w-3xl">{req.description}</p>}

          <div className="text-sm text-white/60 mt-3">
            Status: <span className="text-white/85">{req.status}</span> • Updated: {fmtTime(req.updatedAt)}
          </div>

          {req.reviewNote && (
            <div className="mt-4 rounded-xl border border-white/10 bg-white/5 p-4">
              <div className="text-xs text-white/60">Latest reviewer note</div>
              <div className="text-white/80 mt-1">{req.reviewNote}</div>
            </div>
          )}
        </div>

        <div className="text-xs px-2 py-1 rounded-full border border-white/15 text-white/80">
          Due: {fmtTime(req.dueAt)}
        </div>
      </div>

      <div className="mt-8 grid lg:grid-cols-2 gap-6">
        <VendorEvidenceUpload requestId={req.id} vendorId={ctx.vendorId} />

        <div className="glass-soft p-5">
          <div className="font-semibold">Recent submissions</div>
          <div className="text-sm text-white/70 mt-1">Your last few upload cycles.</div>

          <div className="mt-4 space-y-3">
            {req.iterations.map((it) => (
              <div key={it.id} className="rounded-xl border border-white/10 p-3">
                <div className="flex items-center justify-between">
                  <div className="font-medium">Iteration #{it.id}</div>
                  <div className="text-xs text-white/70">{it.status}</div>
                </div>
                <div className="text-xs text-white/60 mt-1">
                  Created: {fmtTime(it.createdAt)} • Submitted: {fmtTime(it.submittedAt)}
                </div>
                {it.note && <div className="text-sm text-white/75 mt-2">{it.note}</div>}
              </div>
            ))}
            {req.iterations.length === 0 && (
              <div className="text-white/70">No submissions yet. Upload above to begin.</div>
            )}
          </div>
        </div>
      </div>
    </main>
  );
}
