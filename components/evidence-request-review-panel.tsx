// components/evidence-request-review-panel.tsx
"use client";

import { useMemo, useState } from "react";

type EvidenceItem = {
  id: number;
  title: string;
  kind: string | null;
  fileUrl: string | null;
};

type Props = {
  requestId: number;
  status: string;
  evidence: EvidenceItem[];
  initialNote?: string | null;
};

export default function EvidenceRequestReviewPanel({
  requestId,
  status,
  evidence,
  initialNote = null,
}: Props) {
  const [busy, setBusy] = useState<"APPROVE" | "REJECT" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [note, setNote] = useState<string>(initialNote || "");

  const canReview = useMemo(() => status === "SUBMITTED", [status]);

  async function act(action: "APPROVE" | "REJECT") {
    setError(null);
    if (!canReview) return;

    // Require note on reject (polish that feels “enterprise”)
    if (action === "REJECT" && note.trim().length < 3) {
      setError("Please add a short rejection note (at least 3 characters).");
      return;
    }

    setBusy(action);
    try {
      const res = await fetch(`/api/evidence-requests/${requestId}/review`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ action, note: note.trim() }),
      });
      if (!res.ok) {
        const text = await res.text().catch(() => "");
        throw new Error(text || `Request failed (${res.status})`);
      }
      window.location.reload();
    } catch (e: any) {
      setError(e?.message || "Something went wrong.");
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-5 shadow-sm">
      <div className="flex items-center justify-between gap-3">
        <div>
          <div className="text-sm font-semibold text-slate-50">Submission</div>
          <div className="text-xs text-slate-200/70">
            Review the uploaded evidence and approve or reject.
          </div>
        </div>

        <div className="flex items-center gap-2">
          <button
            className={[
              "rounded-full px-4 py-2 text-sm font-semibold",
              canReview
                ? "bg-emerald-500 text-slate-950 hover:bg-emerald-400"
                : "bg-white/10 text-slate-200/60 cursor-not-allowed",
            ].join(" ")}
            disabled={!canReview || busy !== null}
            onClick={() => act("APPROVE")}
          >
            {busy === "APPROVE" ? "Approving…" : "Approve"}
          </button>

          <button
            className={[
              "rounded-full px-4 py-2 text-sm font-semibold",
              canReview
                ? "bg-rose-500/90 text-white hover:bg-rose-500"
                : "bg-white/10 text-slate-200/60 cursor-not-allowed",
            ].join(" ")}
            disabled={!canReview || busy !== null}
            onClick={() => act("REJECT")}
          >
            {busy === "REJECT" ? "Rejecting…" : "Reject"}
          </button>
        </div>
      </div>

      <div className="mt-4 rounded-xl border border-white/10 bg-black/20 p-4">
        <div className="text-xs font-semibold text-slate-200/70">Review note</div>
        <textarea
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Optional on approve. Required on reject."
          className="mt-2 h-24 w-full resize-none rounded-xl border border-white/10 bg-black/30 px-3 py-2 text-sm text-slate-50 outline-none placeholder:text-slate-200/40"
          disabled={!canReview || busy !== null}
        />
        <div className="mt-2 text-xs text-slate-200/60">
          Files attached: <span className="font-semibold text-slate-100">{evidence.length}</span>
        </div>
      </div>

      {error ? (
        <div className="mt-3 rounded-xl border border-rose-500/30 bg-rose-500/10 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      ) : null}

      <div className="mt-4 space-y-2">
        {evidence.length === 0 ? (
          <div className="rounded-xl border border-white/10 bg-black/20 px-4 py-4 text-sm text-slate-200/70">
            No evidence attached to this submission yet.
          </div>
        ) : (
          evidence.map((ev) => (
            <div
              key={ev.id}
              className="flex items-center justify-between gap-4 rounded-xl border border-white/10 bg-black/20 px-4 py-3"
            >
              <div className="min-w-0">
                <div className="truncate text-sm font-semibold text-slate-50">
                  {ev.title || `Evidence #${ev.id}`}
                </div>
                <div className="text-xs text-slate-200/70">
                  {ev.kind ? ev.kind : "FILE"} • ID {ev.id}
                </div>
              </div>

              {ev.fileUrl ? (
                <a
                  href={ev.fileUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="shrink-0 rounded-full border border-white/10 bg-white/10 px-3 py-1.5 text-xs font-semibold text-slate-50 hover:bg-white/15"
                >
                  Open file ↗
                </a>
              ) : null}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
