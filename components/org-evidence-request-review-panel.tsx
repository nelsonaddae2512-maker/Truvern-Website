"use client";

import { useState } from "react";

type Props = {
  evidenceRequestId: number;
  canReview: boolean;
};

export default function OrgEvidenceRequestReviewPanel({ evidenceRequestId, canReview }: Props) {
  const [note, setNote] = useState("");
  const [loading, setLoading] = useState<"APPROVE" | "REJECT" | null>(null);
  const [msg, setMsg] = useState<string | null>(null);

  async function submit(action: "APPROVE" | "REJECT") {
    setMsg(null);
    setLoading(action);
    try {
      const res = await fetch(`/api/org/evidence-requests/${evidenceRequestId}/review`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action, reviewerNote: note }),
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data?.error || "Request failed");
      setMsg(action === "APPROVE" ? "Approved." : "Rejected.");
      // refresh page to show new status/timeline
      window.location.reload();
    } catch (e: any) {
      setMsg(e?.message ?? "Failed");
    } finally {
      setLoading(null);
    }
  }

  return (
    <div className="rounded-2xl border border-white/10 bg-slate-950/30 p-4">
      <div className="text-sm font-semibold text-slate-50">Decision</div>
      <p className="mt-1 text-sm text-slate-200/70">
        Leave a short note for the vendor. On reject, they can resubmit without losing history.
      </p>

      <div className="mt-4">
        <label className="block text-xs font-semibold text-slate-200/70">Review note</label>
        <textarea
          className="mt-2 w-full rounded-xl border border-white/10 bg-white/5 px-3 py-2 text-sm text-slate-100 outline-none placeholder:text-slate-400/60 focus:border-emerald-500/40"
          rows={4}
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="What’s missing / what to improve…"
          disabled={!canReview || !!loading}
        />
      </div>

      <div className="mt-4 flex items-center gap-2">
        <button
          className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-100 hover:bg-white/10 disabled:opacity-50"
          onClick={() => submit("APPROVE")}
          disabled={!canReview || !!loading}
        >
          {loading === "APPROVE" ? "Approving…" : "Approve"}
        </button>

        <button
          className="rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm text-slate-100 hover:bg-white/10 disabled:opacity-50"
          onClick={() => submit("REJECT")}
          disabled={!canReview || !!loading}
        >
          {loading === "REJECT" ? "Rejecting…" : "Reject"}
        </button>

        {msg ? <span className="ml-2 text-xs text-slate-200/70">{msg}</span> : null}
      </div>
    </div>
  );
}
