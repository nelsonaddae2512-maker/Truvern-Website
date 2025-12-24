// app/vendor-portal/evidence-requests/[id]/page.tsx
import Link from "next/link";
import prisma from "@/lib/prisma";
import VendorEvidenceRequestSubmitClient from "@/components/vendor-portal/vendor-evidence-request-submit.client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type ParamsPromise = Promise<{ id: string }>;
type Props = { params: ParamsPromise };

function fmtDateTime(d?: Date | string | null) {
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

export default async function VendorPortalEvidenceRequestDetailPage({ params }: Props) {
  const { id } = await params;
  const requestId = Number(id);

  if (!Number.isFinite(requestId)) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Invalid request id</h1>
        <div className="mt-4">
          <Link className="text-sky-300 hover:underline" href="/vendor-portal/evidence-requests">
            Back to evidence requests
          </Link>
        </div>
      </main>
    );
  }

  const reqRow = await prisma.evidenceRequest.findUnique({
    where: { id: requestId },
    include: {
      iterations: { orderBy: { id: "desc" } as any },
      vendor: true as any,
      evidence: true as any,
    } as any,
  });

  if (!reqRow) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Evidence request not found</h1>
        <div className="mt-4">
          <Link className="text-sky-300 hover:underline" href="/vendor-portal/evidence-requests">
            Back to evidence requests
          </Link>
        </div>
      </main>
    );
  }

  const label = String((reqRow as any).label || "Evidence Request");
  const description = (reqRow as any).description ? String((reqRow as any).description) : "";
  const dueAt = (reqRow as any).dueAt ?? null;

  const vendorId = Number((reqRow as any).vendorId);
  if (!Number.isFinite(vendorId)) {
    return (
      <main className="container-page py-10">
        <h1 className="text-2xl font-semibold text-white">Missing vendor context</h1>
        <p className="mt-2 text-white/70 text-sm">
          This evidence request is not attached to a vendor (vendorId is missing).
        </p>
        <div className="mt-4">
          <Link className="text-sky-300 hover:underline" href="/vendor-portal/evidence-requests">
            Back to evidence requests
          </Link>
        </div>
      </main>
    );
  }

  // Iterations (latest first)
  const iterations: any[] = Array.isArray((reqRow as any).iterations) ? (reqRow as any).iterations : [];
  const latestIter = iterations[0] || null;

  // Effective values: latest iteration wins, fallback to root request
  const effectiveStatus =
    (latestIter?.status ? String(latestIter.status) : "") || String((reqRow as any).status || "UNKNOWN");

  const effectiveSubmittedAt = latestIter?.submittedAt ?? (reqRow as any).submittedAt ?? null;
  const effectiveReviewedAt = latestIter?.reviewedAt ?? (reqRow as any).reviewedAt ?? null;

  const effectiveReviewNote =
    (typeof latestIter?.reviewNote === "string" ? latestIter.reviewNote : "") ||
    (typeof (reqRow as any).reviewNote === "string" ? (reqRow as any).reviewNote : "");

  return (
    <main className="container-page py-10">
      <div className="flex items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-white">{label}</h1>
          {description ? <p className="mt-2 text-sm text-white/70 max-w-2xl">{description}</p> : null}

          <div className="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-2 text-sm">
            <div className="glass-soft rounded-xl px-4 py-3">
              <div className="text-white/60">Status</div>
              <div className="text-white font-medium">{effectiveStatus}</div>
            </div>
            <div className="glass-soft rounded-xl px-4 py-3">
              <div className="text-white/60">Due</div>
              <div className="text-white font-medium">{fmtDateTime(dueAt)}</div>
            </div>
            <div className="glass-soft rounded-xl px-4 py-3">
              <div className="text-white/60">Submitted</div>
              <div className="text-white font-medium">{fmtDateTime(effectiveSubmittedAt)}</div>
            </div>
            <div className="glass-soft rounded-xl px-4 py-3">
              <div className="text-white/60">Reviewed</div>
              <div className="text-white font-medium">{fmtDateTime(effectiveReviewedAt)}</div>
            </div>
          </div>

          {effectiveReviewNote ? (
            <div className="mt-4 glass-soft rounded-xl px-4 py-3">
              <div className="text-white/60 text-sm">Review note</div>
              <div className="text-white mt-1">{effectiveReviewNote}</div>
            </div>
          ) : null}
        </div>

        <div className="shrink-0">
          <Link className="btn-glass" href="/vendor-portal/evidence-requests">
            Back
          </Link>
        </div>
      </div>

      <div className="mt-8">
        {effectiveStatus === "APPROVED" ? (
          <div className="glass-soft rounded-2xl p-5">
            <div className="text-white font-semibold">Approved ✅</div>
            <div className="text-white/70 text-sm mt-1">No further action is required.</div>
          </div>
        ) : (
          <VendorEvidenceRequestSubmitClient
            vendorId={vendorId}
            evidenceRequestId={requestId}
            status={effectiveStatus}
            defaultTitle={label}
          />
        )}
      </div>
    </main>
  );
}
