// app/org/evidence-requests/[id]/print/page.tsx
import prisma from "@/lib/prisma";

export const dynamic = "force-dynamic";
export const revalidate = 0;

type ParamsPromise = Promise<{ id: string }>;
type Props = { params: ParamsPromise };

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

function toIntId(raw: unknown): number | null {
  const v = Array.isArray(raw) ? raw[0] : raw;
  const s = typeof v === "string" ? v.trim() : v == null ? "" : String(v);
  const n = Number(s);
  return Number.isFinite(n) && n > 0 ? n : null;
}

export default async function EvidenceRequestPrintPage({ params }: Props) {
  const p = await params; // IMPORTANT: matches your app’s ParamsPromise pattern
  const requestId = toIntId(p?.id);

  if (!requestId) {
    return (
      <main className="p-10 bg-white text-black">
        <h1 className="text-xl font-semibold">Invalid request id</h1>
      </main>
    );
  }

  const req = await prisma.evidenceRequest.findUnique({
    where: { id: requestId },
    include: {
      vendor: { select: { id: true, name: true } },
      iterations: { orderBy: { id: "desc" }, include: { files: true } },
      evidence: true,
    },
  });

  if (!req) {
    return (
      <main className="p-10 bg-white text-black">
        <h1 className="text-xl font-semibold">Evidence request not found</h1>
        <div className="mt-2 text-sm text-gray-600">Request #{requestId}</div>
      </main>
    );
  }

  const latestIteration = req.iterations?.[0] ?? null;
  const files = latestIteration?.files?.length ? latestIteration.files : req.evidence ?? [];

  return (
    <html>
      <head>
        <title>Evidence Request #{req.id} — Print</title>
        <style>{`
          @page { size: Letter; margin: 0.75in; }
          .page-break { page-break-before: always; }
          .muted { color: #4b5563; }
          .label { font-weight: 600; }
        `}</style>
      </head>
      <body className="bg-white text-black">
        <main style={{ maxWidth: 900, margin: "0 auto", padding: "24px 0" }}>
          {/* Header */}
          <header style={{ borderBottom: "1px solid #e5e7eb", paddingBottom: 12, marginBottom: 18 }}>
            <div style={{ display: "flex", justifyContent: "space-between", gap: 12 }}>
              <div>
                <div style={{ fontSize: 22, fontWeight: 700 }}>Evidence Request</div>
                <div className="muted" style={{ marginTop: 4, fontSize: 13 }}>
                  <span className="label">Request:</span> #{req.id}{" "}
                  <span style={{ margin: "0 8px" }}>•</span>
                  <span className="label">Vendor:</span> {req.vendor?.name ?? `Vendor #${req.vendorId}`}{" "}
                  <span style={{ margin: "0 8px" }}>•</span>
                  <span className="label">Kind:</span> {String(req.kind || "—")}{" "}
                  <span style={{ margin: "0 8px" }}>•</span>
                  <span className="label">Status:</span> {String(req.status || "—")}
                </div>
              </div>
              <div className="muted" style={{ fontSize: 12, textAlign: "right" }}>
                Generated: {new Date().toLocaleString()}
                <div>Created: {fmtDate(req.createdAt)}</div>
              </div>
            </div>
          </header>

          {/* Summary */}
          <section style={{ marginBottom: 18 }}>
            <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 8 }}>Audit note</div>
            <div style={{ border: "1px solid #e5e7eb", borderRadius: 10, padding: 12, fontSize: 13, whiteSpace: "pre-wrap" }}>
              {req.reviewNote || "—"}
            </div>
          </section>

          {/* Files */}
          <section style={{ marginBottom: 18 }}>
            <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 8 }}>
              Submitted Evidence ({files.length})
            </div>

            {files.length === 0 ? (
              <div className="muted" style={{ fontSize: 13 }}>No files submitted.</div>
            ) : (
              <div style={{ display: "grid", gap: 10 }}>
                {files.map((f) => (
                  <div key={f.id} style={{ border: "1px solid #e5e7eb", borderRadius: 12, padding: 12 }}>
                    <div style={{ fontWeight: 700, fontSize: 14 }}>{f.title}</div>
                    <div className="muted" style={{ marginTop: 4, fontSize: 12 }}>
                      Kind: {String(f.kind || "—")} • Uploaded: {fmtTime(f.uploadedAt)}
                    </div>
                    {f.description ? (
                      <div style={{ marginTop: 8, fontSize: 13, whiteSpace: "pre-wrap" }}>{f.description}</div>
                    ) : null}
                    {f.fileUrl ? (
                      <div className="muted" style={{ marginTop: 8, fontSize: 11, wordBreak: "break-all" }}>
                        {f.fileUrl}
                      </div>
                    ) : null}
                  </div>
                ))}
              </div>
            )}
          </section>

          {/* Timeline */}
          <section className="page-break">
            <div style={{ fontSize: 16, fontWeight: 700, marginBottom: 8 }}>Timeline</div>
            {req.iterations?.length ? (
              <div style={{ display: "grid", gap: 10 }}>
                {req.iterations.map((it) => (
                  <div key={it.id} style={{ border: "1px solid #e5e7eb", borderRadius: 12, padding: 12 }}>
                    <div style={{ fontWeight: 700, fontSize: 13 }}>
                      Iteration #{it.id} • {String(it.status || "—")}
                    </div>
                    <div className="muted" style={{ marginTop: 4, fontSize: 12 }}>
                      Submitted: {fmtTime(it.submittedAt)} • Reviewed: {fmtTime(it.reviewedAt)}
                      {it.submittedBy ? <> • By: {it.submittedBy}</> : null}
                    </div>
                    {it.reviewerNote ? (
                      <div style={{ marginTop: 8, fontSize: 13, whiteSpace: "pre-wrap" }}>{it.reviewerNote}</div>
                    ) : null}
                    <div className="muted" style={{ marginTop: 8, fontSize: 12 }}>
                      Files in iteration: {it.files?.length ?? 0}
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="muted" style={{ fontSize: 13 }}>No iterations recorded.</div>
            )}
          </section>

          <footer className="muted" style={{ marginTop: 18, paddingTop: 12, borderTop: "1px solid #e5e7eb", fontSize: 11 }}>
            Truvern • Print-ready audit packet • Evidence Request #{req.id}
          </footer>
        </main>
      </body>
    </html>
  );
}
