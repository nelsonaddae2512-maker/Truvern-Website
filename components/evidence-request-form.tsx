"use client";

import { useState } from "react";

type Props = {
  vendorId: number;
  organizationId: number | null;
};

const KINDS = [
  { value: "SOC2", label: "SOC 2 Report" },
  { value: "ISO27001", label: "ISO 27001 Certificate" },
  { value: "PEN_TEST", label: "Pen Test Report" },
  { value: "POLICY", label: "Security Policy" },
  { value: "BCP_DRP", label: "BCP / DR Plan" },
  { value: "DPIA", label: "DPIA" },
  { value: "OTHER", label: "Other" },
];

export default function EvidenceRequestForm({ vendorId, organizationId }: Props) {
  const [kind, setKind] = useState("SOC2");
  const [label, setLabel] = useState("SOC 2 Type II Report");
  const [description, setDescription] = useState("");
  const [dueAt, setDueAt] = useState<string>("");
  const [loading, setLoading] = useState(false);
  const [msg, setMsg] = useState<string | null>(null);

  async function onSubmit() {
    setLoading(true);
    setMsg(null);
    try {
      const res = await fetch("/api/evidence-requests", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          vendorId,
          organizationId,
          kind,
          label,
          description: description || null,
          dueAt: dueAt ? new Date(dueAt).toISOString() : null,
        }),
      });

      const data = await res.json();
      if (!res.ok || !data?.ok) throw new Error(data?.error || "Failed");

      setMsg("Evidence request created.");
      setDescription("");
    } catch (e: any) {
      setMsg(e?.message ?? "Failed to create request.");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="space-y-4">
      <div className="text-sm font-semibold text-slate-50">Request details</div>

      <div className="grid gap-3 md:grid-cols-2">
        <label className="space-y-1">
          <div className="text-xs text-slate-200/60">Type</div>
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value)}
            className="w-full rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2 text-sm text-slate-100 outline-none"
          >
            {KINDS.map((k) => (
              <option key={k.value} value={k.value}>
                {k.label}
              </option>
            ))}
          </select>
        </label>

        <label className="space-y-1">
          <div className="text-xs text-slate-200/60">Due date (optional)</div>
          <input
            type="datetime-local"
            value={dueAt}
            onChange={(e) => setDueAt(e.target.value)}
            className="w-full rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2 text-sm text-slate-100 outline-none"
          />
        </label>
      </div>

      <label className="space-y-1 block">
        <div className="text-xs text-slate-200/60">Label</div>
        <input
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          className="w-full rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2 text-sm text-slate-100 outline-none"
        />
      </label>

      <label className="space-y-1 block">
        <div className="text-xs text-slate-200/60">Instructions (optional)</div>
        <textarea
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          rows={4}
          className="w-full rounded-xl border border-white/10 bg-slate-950/60 px-3 py-2 text-sm text-slate-100 outline-none"
          placeholder="Please upload the most recent SOC 2 Type II report (last 12 months)…"
        />
      </label>

      <div className="flex items-center gap-2">
        <button
          onClick={onSubmit}
          disabled={loading}
          className="rounded-full bg-emerald-500 px-4 py-2 text-sm font-semibold text-slate-950 hover:bg-emerald-400 disabled:opacity-60"
        >
          {loading ? "Creating…" : "Create request"}
        </button>

        {msg ? <div className="text-sm text-slate-200/70">{msg}</div> : null}
      </div>

      <div className="text-xs text-slate-200/50">
        Enterprise note: this request is visible to the vendor in Vendor Portal → Evidence requests.
      </div>
    </div>
  );
}
