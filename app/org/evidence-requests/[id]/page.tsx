import Link from "next/link";
import prisma from "@/lib/prisma";
import { revalidatePath } from "next/cache";
import EvidenceRequestReviewActions from "@/components/org/evidence-request-review-actions.client";
import EvidenceRequestExportButton from "@/components/org/evidence-request-export-button.client";
import CopyLinkButton from "@/components/ui/copy-link-button.client";

export const dynamic = "force-dynamic";
export const revalidate = 0;

type ParamsPromise = Promise<{ id: string }>;
type Props = {
  params: ParamsPromise;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
};

function clsx(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

function fmtDate(d?: Date | string | null) {
  if (!d) return "—";
  const dt = typeof d === "string" ? new Date(d) : d;
  return dt.toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" });
}

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

function badge(status: string) {
  const s = (status || "").toUpperCase();
  const base =
    "inline-flex items-center rounded-full px-2.5 py-1 text-xs font-semibold tracking-wide border";
  const map: Record<string, string> = {
    OPEN: "bg-white/5 border-white/10 text-white/80",
    SUBMITTED: "bg-sky-500/10 border-sky-400/20 text-sky-200",
    APPROVED: "bg-emerald-500/10 border-emerald-400/20 text-emerald-200",
    REJECTED: "bg-rose-500/10 border-rose-400/20 text-rose-200",
    CANCELLED: "bg-zinc-500/10 border-zinc-400/20 text-zinc-200",
    SUPERSEDED: "bg-amber-500/10 border-amber-400/20 text-amber-200",
    LATEST: "bg-sky-500/10 border-sky-400/20 text-sky-200",
    VIEWING: "bg-white/5 border-white/10 text-white/85",
  };
  return (
    <span className={clsx(base, map[s] || "bg-white/5 border-white/10 text-white/80")}>{s}</span>
  );
}

function bannerFor(status: string) {
  const s = (status || "").toUpperCase();
  const base = "glass-soft rounded-2xl p-4 border";

  if (s === "OPEN") {
    return (
      <div className={clsx(base, "border-white/10")}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-white">Awaiting vendor submission</div>
            <div className="mt-1 text-sm text-white/70">
              This request is open but not yet submitted by the vendor. Approval actions unlock
              after submission.
            </div>
          </div>
          {badge(s)}
        </div>
      </div>
    );
  }

  if (s === "SUBMITTED") {
    return (
      <div className={clsx(base, "border-sky-400/20 bg-sky-500/5")}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-white">Submission ready for review</div>
            <div className="mt-1 text-sm text-white/70">
              Review the files, add a note if needed, then approve or reject.
            </div>
          </div>
          {badge(s)}
        </div>
      </div>
    );
  }

  if (s === "APPROVED") {
    return (
      <div className={clsx(base, "border-emerald-400/20 bg-emerald-500/5")}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-white">Approved</div>
            <div className="mt-1 text-sm text-white/70">
              Approval and notes are recorded for audit and board reporting.
            </div>
          </div>
          {badge(s)}
        </div>
      </div>
    );
  }

  if (s === "REJECTED") {
    return (
      <div className={clsx(base, "border-rose-400/20 bg-rose-500/5")}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-white">Rejected</div>
            <div className="mt-1 text-sm text-white/70">
              The vendor should re-submit a new iteration addressing your review note.
            </div>
          </div>
          {badge(s)}
        </div>
      </div>
    );
  }

  if (s === "CANCELLED") {
    return (
      <div className={clsx(base, "border-zinc-400/20 bg-zinc-500/5")}>
        <div className="flex items-start justify-between gap-3">
          <div>
            <div className="text-sm font-semibold text-white">Cancelled</div>
            <div className="mt-1 text-sm text-white/70">
              This request was cancelled. No further submissions or review actions are expected.
            </div>
          </div>
          {badge(s)}
        </div>
      </div>
    );
  }

  return (
    <div className={clsx(base, "border-white/10")}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="text-sm font-semibold text-white">Request</div>
          <div className="mt-1 text-sm text-white/70">Status: {s || "—"}</div>
        </div>
        {badge(s)}
      </div>
    </div>
  );
}

function parseIntFromSearchParam(v: string | string[] | undefined): number | null {
  const raw = Array.isArray(v) ? v[0] : v;
  if (!raw) return null;
  const n = Number(String(raw).trim());
  if (!Number.isFinite(n)) return null;
  return n;
}

type EvidenceRow = {
  id: number;
  title: string;
  description: string | null;
  fileUrl: string | null;
  kind: string;
  uploadedAt: Date | string;
};

export default async function OrgEvidenceRequestDetailPage({ params, searchParams }: Props) {
  const { id } = await params;
  const requestId = Number(id);

  const sp = (await searchParams) || {};
  const requestedIterationId = parseIntFromSearchParam(sp.it);

  if (!requestId || Number.isNaN(requestId)) {
    return (
      <main className="container-page py-16">
        <h1 className="text-2xl font-semibold text-white">Invalid request id</h1>
        <div className="mt-6">
          <Link className="btn-glass" href="/org/evidence-requests">
            Back to Evidence Requests
          </Link>
        </div>
      </main>
    );
  }

  const request = await prisma.evidenceRequest.findUnique({
    where: { id: requestId },
    include: {
      vendor: { select: { id: true, name: true } },
      evidence: {
        select: {
          id: true,
          title: true,
          description: true,
          fileUrl: true,
          kind: true,
          uploadedAt: true,
        },
        orderBy: { id: "desc" },
      },
      iterations: {
        orderBy: { id: "desc" },
        select: {
          id: true,
          status: true,
          submittedBy: true,
          submittedAt: true,
          reviewedAt: true,
          reviewerNote: true,
          createdAt: true,
          files: {
            select: {
              id: true,
              title: true,
              description: true,
              fileUrl: true,
              kind: true,
              uploadedAt: true,
            },
            orderBy: { id: "desc" },
          },
        },
      },
    },
  });

  if (!request) {
    return (
      <main className="container-page py-16">
        <h1 className="text-2xl font-semibold text-white">Evidence request not found</h1>
        <div className="mt-6">
          <Link className="btn-glass" href="/org/evidence-requests">
            Back to Evidence Requests
          </Link>
        </div>
      </main>
    );
  }

  const status = String(request.status || "").toUpperCase();
  const title = (request.label && request.label.trim()) || `Evidence request #${requestId}`;
  const vendorName = request.vendor?.name || `Vendor #${request.vendorId}`;
  const kind = String(request.kind || "—").toUpperCase();

  const iterations = request.iterations || [];
  const iterationsCount = iterations.length;

  const latestIteration = iterations[0] || null;
  const latestIterationId = latestIteration?.id ?? null;

  const selectedIteration =
    requestedIterationId != null
      ? iterations.find((it) => it.id === requestedIterationId) || null
      : null;

  const activeIteration = selectedIteration || latestIteration;
  const viewingIterationId = activeIteration?.id ?? null;

  const isViewingLatest =
    viewingIterationId != null && latestIterationId != null
      ? viewingIterationId === latestIterationId
      : true;

  const activeFiles: EvidenceRow[] =
    (activeIteration?.files as any as EvidenceRow[])?.length
      ? (activeIteration.files as any as EvidenceRow[])
      : ((request.evidence as any as EvidenceRow[]) || []);

  const filesCount = activeFiles.length;

  const createdAt = request.createdAt;
  const submittedAt = (activeIteration?.submittedAt as any) ?? request.submittedAt ?? null;
  const reviewedAt = (activeIteration?.reviewedAt as any) ?? request.reviewedAt ?? null;

  const reviewNote = request.reviewNote ?? null;
  const iterationReviewerNote = (activeIteration?.reviewerNote as any) ?? null;

  const canReview = status === "SUBMITTED" && isViewingLatest;
  const isWaiting = status === "OPEN";
  const isFinal = status === "APPROVED" || status === "REJECTED" || status === "CANCELLED";

  const iterationIndexFromLatest = viewingIterationId
    ? iterations.findIndex((it) => it.id === viewingIterationId)
    : -1;

  const iterationNumber = iterationIndexFromLatest >= 0 ? iterationIndexFromLatest + 1 : null;

  const latestPath = `/org/evidence-requests/${requestId}`;
  const viewPath = `${latestPath}${viewingIterationId ? `?it=${viewingIterationId}` : ""}`;

  // Phase 331D: vendor resubmission link (CONFIRMED route)
  const vendorResubmitHref = `/vendor-portal/evidence-requests/${requestId}`;

  return (
    <main className="container-page py-10">
      <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <h1 className="text-2xl font-semibold text-white">{title}</h1>
            {badge(status)}
            {iterationNumber != null ? (
              <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-xs font-semibold text-white/80">
                Iteration #{iterationNumber}
                <span className="text-white/30">/</span>
                <span className="text-white/60">{iterationsCount || 1}</span>
              </span>
            ) : null}
            {!isViewingLatest ? badge("SUPERSEDED") : badge("LATEST")}
          </div>

          <div className="mt-2 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div className="text-sm text-white/70">
              Vendor: <span className="text-white/90 font-medium">{vendorName}</span>
              <span className="mx-2 text-white/30">•</span>
              Kind: <span className="text-white/90 font-medium">{kind}</span>
              <span className="mx-2 text-white/30">•</span>
              Created: <span className="text-white/90 font-medium">{fmtDate(createdAt)}</span>
            </div>

            {/* Iteration selector (331D: include file counts) */}
            {iterationsCount > 1 ? (
              <div className="flex items-center gap-2">
                <span className="text-xs text-white/55">View:</span>
                <select
                  className={clsx(
                    "rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-white/90",
                    "focus:outline-none focus:ring-2 focus:ring-white/10"
                  )}
                  defaultValue={isViewingLatest ? "latest" : String(viewingIterationId ?? "")}
                  onChange={(e) => {
                    const v = e.target.value;
                    if (v === "latest") window.location.href = latestPath;
                    else window.location.href = `${latestPath}?it=${encodeURIComponent(v)}`;
                  }}
                >
                  <option value="latest">Latest</option>
                  {iterations.map((it, idx) => {
                    const num = idx + 1; // desc ordering => latest is #1
                    const count = (it.files?.length ?? 0) as number;
                    return (
                      <option key={it.id} value={String(it.id)}>
                        Iteration #{num} ({count} file{count === 1 ? "" : "s"})
                      </option>
                    );
                  })}
                </select>

                {!isViewingLatest ? (
                  <Link className="btn-glass px-3 py-2 text-sm" href={latestPath} title="Jump to latest">
                    Latest
                  </Link>
                ) : null}
              </div>
            ) : null}
          </div>

          {/* Phase 331D: Rejected resubmission CTA (org-side) */}
          {status === "REJECTED" ? (
            <div className="mt-3 rounded-2xl border border-rose-400/20 bg-rose-500/5 p-3">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-white">Request resubmission</div>
                  <div className="mt-1 text-sm text-white/70">
                    Share the vendor upload link so they can submit a new iteration addressing your review note.
                  </div>
                  <div className="mt-2 text-xs text-white/55">
                    Vendor route detected:{" "}
                    <span className="text-white/80 font-semibold">/vendor-portal/evidence-requests/[id]</span>
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <CopyLinkButton
                    href={vendorResubmitHref}
                    className="btn-glass px-2.5"
                    variant="icon"
                    ariaLabel="Copy vendor resubmission link"
                    tooltip="Copy vendor resubmission link"
                  />
                  <a
                    className="btn-glass"
                    href={vendorResubmitHref}
                    target="_blank"
                    rel="noreferrer"
                    title="Open vendor resubmission link in a new tab"
                  >
                    Open vendor link
                  </a>
                </div>
              </div>
            </div>
          ) : null}

          {!isViewingLatest ? (
            <div className="mt-3 rounded-2xl border border-amber-400/20 bg-amber-500/5 p-3">
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <div className="text-sm font-semibold text-white">Superseded iteration</div>
                  <div className="mt-1 text-sm text-white/70">
                    You’re viewing an older iteration. Review actions are locked to prevent approving/rejecting stale submissions.
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  <Link className="btn-glass" href={latestPath} title="Return to the latest iteration">
                    View latest
                  </Link>
                  <CopyLinkButton
                    href={viewPath}
                    className="btn-glass px-2.5"
                    variant="icon"
                    ariaLabel="Copy link"
                    tooltip="Copy a shareable link to this iteration"
                  />
                </div>
              </div>
            </div>
          ) : null}

          <div className="mt-4 flex flex-wrap items-start gap-2">
            <Link className="btn-glass" href="/org/evidence-requests">
              Back
            </Link>

            {request.vendor?.id ? (
              <Link className="btn-glass" href={`/vendors/${request.vendor.id}`}>
                View vendor
              </Link>
            ) : null}

            <CopyLinkButton
              href={viewPath}
              className="btn-glass px-2.5"
              variant="icon"
              ariaLabel="Copy link"
              tooltip="Copy a shareable link to this view"
            />

            <EvidenceRequestExportButton
              requestId={requestId}
              vendorId={request.vendor?.id ?? null}
              href={`/org/evidence-requests/${requestId}/print`}
              className="btn-glass px-2.5"
              variant="icon"
              ariaLabel="Print / Export"
              showHint={false}
            />
          </div>
        </div>

        <div className="w-full md:w-[520px]">{bannerFor(status)}</div>
      </div>

      <div className="mt-8 grid gap-6 lg:grid-cols-2">
        {/* LEFT */}
        <section className="glass-soft rounded-2xl p-5 border border-white/10">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-white">Submission</h2>

            {/* Phase 331D: "badge-like" active files indicator */}
            <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-xs font-semibold text-white/75">
              Active files
              <span className="rounded-full bg-white/10 px-2 py-0.5 text-white/90">{filesCount}</span>
            </span>
          </div>

          <div className="mt-4">
            <EvidenceRequestReviewActions
              requestId={requestId}
              status={status}
              initialReviewNote={reviewNote || ""}
              canReview={canReview}
              isWaiting={isWaiting}
              isFinal={isFinal}
              showExport={false}
              onRevalidate={async () => {
                "use server";
                revalidatePath(`/org/evidence-requests/${requestId}`);
              }}
            />
          </div>

          <div className="mt-6 border-t border-white/10 pt-4">
            <div className="flex items-center justify-between">
              <div className="text-sm font-semibold text-white">Files</div>
              {viewingIterationId != null ? (
                <div className="text-xs text-white/55">Viewing iteration id #{viewingIterationId}</div>
              ) : null}
            </div>

            {filesCount === 0 ? (
              <div className="mt-2 text-sm text-white/60">No files submitted yet.</div>
            ) : (
              <ul className="mt-3 space-y-2">
                {activeFiles.map((ev, idx) => {
                  const evTitle =
                    (typeof ev?.title === "string" && ev.title.trim()) ||
                    (ev?.id != null ? `Evidence #${ev.id}` : `Evidence ${idx + 1}`);

                  return (
                    <li
                      key={ev?.id ?? `ev-${idx}`}
                      className="rounded-xl border border-white/10 bg-white/5 p-3"
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <div className="truncate text-sm font-medium text-white">{evTitle}</div>
                          <div className="mt-1 text-xs text-white/60">
                            Kind:{" "}
                            <span className="text-white/80 font-semibold">
                              {String(ev?.kind || "—").toUpperCase()}
                            </span>
                            <span className="mx-1 text-white/30">•</span>
                            Uploaded: {fmtTime(ev?.uploadedAt as any)}
                          </div>
                          {ev?.description ? (
                            <div className="mt-2 text-sm text-white/75 whitespace-pre-wrap">
                              {ev.description}
                            </div>
                          ) : null}
                        </div>

                        {ev?.fileUrl ? (
                          <div className="shrink-0">
                            <a className="btn-glass" href={ev.fileUrl} target="_blank" rel="noreferrer">
                              Open
                            </a>
                          </div>
                        ) : null}
                      </div>
                    </li>
                  );
                })}
              </ul>
            )}
          </div>
        </section>

        {/* RIGHT */}
        <section className="glass-soft rounded-2xl p-5 border border-white/10">
          <h2 className="text-base font-semibold text-white">Request metadata</h2>

          <dl className="mt-4 grid grid-cols-2 gap-x-6 gap-y-4 text-sm">
            <div>
              <dt className="text-white/60">Kind</dt>
              <dd className="mt-1 text-white/90 font-medium">{kind}</dd>
            </div>
            <div>
              <dt className="text-white/60">Created</dt>
              <dd className="mt-1 text-white/90 font-medium">{fmtDate(createdAt)}</dd>
            </div>
            <div>
              <dt className="text-white/60">Submitted</dt>
              <dd className="mt-1 text-white/90 font-medium">{fmtDate(submittedAt)}</dd>
            </div>
            <div>
              <dt className="text-white/60">Reviewed</dt>
              <dd className="mt-1 text-white/90 font-medium">{fmtDate(reviewedAt)}</dd>
            </div>
            <div>
              <dt className="text-white/60">Active iteration</dt>
              <dd className="mt-1 text-white/90 font-medium">
                {viewingIterationId != null ? `#${viewingIterationId}` : "—"}
                {!isViewingLatest && latestIterationId != null ? (
                  <span className="ml-2 text-xs text-white/50">(latest: #{latestIterationId})</span>
                ) : null}
              </dd>
            </div>
            <div>
              <dt className="text-white/60">Status</dt>
              <dd className="mt-1">{badge(status)}</dd>
            </div>
          </dl>

          <div className="mt-6">
            <div className="text-sm font-semibold text-white">Reviewer note (audit)</div>
            <div className="mt-2 rounded-xl border border-white/10 bg-white/5 p-3">
              <div className="text-sm whitespace-pre-wrap text-white/85">{reviewNote || "—"}</div>
            </div>

            {iterationReviewerNote ? (
              <div className="mt-4">
                <div className="text-sm font-semibold text-white">Reviewer note (iteration)</div>
                <div className="mt-2 rounded-xl border border-white/10 bg-white/5 p-3">
                  <div className="text-sm whitespace-pre-wrap text-white/85">{iterationReviewerNote}</div>
                </div>
              </div>
            ) : null}
          </div>

          <div className="mt-6">
            <div className="text-sm font-semibold text-white">Timeline</div>

            {iterations.length ? (
              <ol className="mt-3 space-y-2">
                {iterations.map((it, idx) => {
                  const itId = it.id;
                  const isActive = viewingIterationId === itId;
                  const isLatest = idx === 0;
                  const itFiles = it.files?.length ?? 0;

                  return (
                    <li
                      key={it.id}
                      className={clsx(
                        "rounded-xl border bg-white/5 p-3",
                        isActive ? "border-sky-400/30" : "border-white/10"
                      )}
                    >
                      <div className="flex items-start justify-between gap-3">
                        <div className="min-w-0">
                          <div className="flex flex-wrap items-center gap-2">
                            <div className="text-sm font-medium text-white">Iteration #{idx + 1}</div>
                            {isActive ? badge("VIEWING") : null}
                            {isLatest ? badge("LATEST") : null}
                            <span className="text-xs text-white/55">• {itFiles} file{itFiles === 1 ? "" : "s"}</span>
                          </div>

                          <div className="mt-1 text-xs text-white/60">
                            Status:{" "}
                            <span className="text-white/80 font-semibold">
                              {String(it.status || "—").toUpperCase()}
                            </span>
                            <span className="mx-1 text-white/30">•</span>
                            Created: {fmtTime(it.createdAt)}
                            {it.submittedAt ? (
                              <>
                                <span className="mx-1 text-white/30">•</span> Submitted: {fmtTime(it.submittedAt)}
                              </>
                            ) : null}
                            {it.reviewedAt ? (
                              <>
                                <span className="mx-1 text-white/30">•</span> Reviewed: {fmtTime(it.reviewedAt)}
                              </>
                            ) : null}
                          </div>

                          {it.submittedBy ? (
                            <div className="mt-2 text-xs text-white/60">
                              Submitted by:{" "}
                              <span className="text-white/80 font-semibold">{it.submittedBy}</span>
                            </div>
                          ) : null}

                          {it.reviewerNote ? (
                            <div className="mt-2 text-sm whitespace-pre-wrap text-white/80">{it.reviewerNote}</div>
                          ) : null}
                        </div>

                        {/* Phase 331D: open in new tab */}
                        <div className="shrink-0 flex flex-col items-end gap-2">
                          {badge(String(it.status || "").toUpperCase())}
                          <a
                            className="btn-glass px-3 py-1 text-xs"
                            href={`/org/evidence-requests/${requestId}?it=${itId}`}
                            target="_blank"
                            rel="noreferrer"
                            title={`Open iteration in a new tab (id ${itId})`}
                          >
                            Open ↗
                          </a>
                        </div>
                      </div>
                    </li>
                  );
                })}
              </ol>
            ) : (
              <div className="mt-3 rounded-xl border border-white/10 bg-white/5 p-4">
                <div className="text-sm font-semibold text-white">No iterations yet</div>
                <div className="mt-1 text-sm text-white/65">
                  This request has no iteration history recorded.
                </div>
                <div className="mt-3 flex items-center gap-2">
                  <CopyLinkButton
                    href={latestPath}
                    className="btn-glass px-2.5"
                    variant="icon"
                    ariaLabel="Copy link"
                    tooltip="Copy a shareable link to this request"
                  />
                  <Link className="btn-glass px-3 py-2 text-sm" href={latestPath}>
                    Refresh
                  </Link>
                </div>
              </div>
            )}
          </div>
        </section>
      </div>
    </main>
  );
}
