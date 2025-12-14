"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

type TemplateChoice = {
  id: number;
  name: string;
  description: string | null;
  standard: string | null;
  category: string | null;
  version: string | null;
};

type Props = {
  vendorId: number;
  vendorName: string;
  templates: TemplateChoice[];
};

export default function AssessmentStartChooser({
  vendorId,
  vendorName,
  templates,
}: Props) {
  const router = useRouter();
  const [selectedTemplateId, setSelectedTemplateId] = useState<number | null>(
    templates[0]?.id ?? null
  );
  const [title, setTitle] = useState("");
  const [dueAt, setDueAt] = useState<string>("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleStart() {
    if (!selectedTemplateId) {
      setError("Select a template to start.");
      return;
    }

    try {
      setSubmitting(true);
      setError(null);

      const res = await fetch(`/api/vendors/${vendorId}/assessments`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          templateId: selectedTemplateId,
          title: title.trim() || undefined,
          dueAt: dueAt || null,
        }),
      });

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.error || "Failed to start assessment");
      }

      const data = await res.json();

      if (data.redirectUrl) {
        router.push(data.redirectUrl);
      } else if (data.id) {
        router.push(`/assessments/${data.id}/run`);
      }
    } catch (err: any) {
      console.error(err);
      setError(err.message ?? "Failed to start assessment");
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <section className="rounded-3xl border border-slate-800 bg-slate-950/80 px-4 py-4 shadow-lg shadow-black/40">
        <div className="flex flex-col gap-2 md:flex-row md:items-center md:justify-between">
          <div>
            <div className="inline-flex items-center gap-2 rounded-full bg-slate-900/70 border border-emerald-500/30 px-3 py-1 mb-2">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-400" />
              <span className="text-[10px] font-semibold tracking-[0.2em] text-emerald-300 uppercase">
                Start assessment
              </span>
            </div>
            <h1 className="text-2xl font-semibold text-slate-50 tracking-tight">
              New assessment for{" "}
              <span className="text-emerald-300">{vendorName}</span>
            </h1>
            <p className="mt-1 text-[11px] text-slate-500">
              Choose a template, set an optional due date, and Truvern will
              track scores and vendor risk automatically.
            </p>
          </div>
        </div>

        {error && (
          <div className="mt-3 rounded-2xl border border-rose-500/60 bg-rose-950/40 px-3 py-2 text-[11px] text-rose-100">
            {error}
          </div>
        )}
      </section>

      {/* Content */}
      <section className="rounded-3xl border border-slate-800 bg-slate-950/80 px-4 py-4 shadow-lg shadow-black/40">
        <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,2fr)_minmax(0,1.2fr)] gap-4">
          {/* Template list */}
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400 mb-2">
              Assessment templates
            </p>
            {templates.length === 0 ? (
              <p className="text-[12px] text-slate-500 border border-dashed border-slate-700 rounded-2xl px-3 py-4 bg-slate-950/70">
                No active templates found. Create one in{" "}
                <span className="text-emerald-300">Assessment Templates</span>{" "}
                first.
              </p>
            ) : (
              <div className="space-y-2 max-h-[360px] overflow-y-auto pr-1">
                {templates.map((t) => {
                  const isSelected = t.id === selectedTemplateId;
                  return (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => setSelectedTemplateId(t.id)}
                      className={`w-full rounded-2xl px-3 py-2 text-left text-[12px] transition border ${
                        isSelected
                          ? "border-emerald-400/60 bg-slate-800/90 text-emerald-200 shadow shadow-emerald-500/20"
                          : "border-slate-800 bg-slate-950 text-slate-200 hover:border-emerald-400/50 hover:text-emerald-200"
                      }`}
                    >
                      <div className="flex items-center justify-between gap-2 mb-0.5">
                        <span className="font-semibold truncate">
                          {t.name}
                        </span>
                        {t.version && (
                          <span className="text-[10px] text-slate-500">
                            {t.version}
                          </span>
                        )}
                      </div>
                      <div className="flex flex-wrap gap-2">
                        {t.standard && (
                          <span className="inline-flex items-center rounded-full border border-slate-700 bg-slate-900/80 px-2 py-0.5 text-[10px] text-slate-300">
                            {t.standard}
                          </span>
                        )}
                        {t.category && (
                          <span className="inline-flex items-center rounded-full border border-slate-700 bg-slate-900/80 px-2 py-0.5 text-[10px] text-slate-400">
                            {t.category}
                          </span>
                        )}
                      </div>
                      {t.description && (
                        <p className="mt-1 text-[11px] text-slate-400 line-clamp-2">
                          {t.description}
                        </p>
                      )}
                    </button>
                  );
                })}
              </div>
            )}
          </div>

          {/* Meta form */}
          <div className="flex flex-col justify-between gap-4">
            <div className="space-y-3">
              <div>
                <label className="block text-[11px] font-medium text-slate-400">
                  Assessment title
                </label>
                <input
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  className="mt-1 w-full rounded-xl border border-slate-700 bg-slate-900/80 px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500/60 focus:border-emerald-400"
                  placeholder="e.g., 2025 SOC2 Core for Vendor X"
                />
              </div>
              <div>
                <label className="block text-[11px] font-medium text-slate-400">
                  Due date (optional)
                </label>
                <input
                  type="date"
                  value={dueAt}
                  onChange={(e) => setDueAt(e.target.value)}
                  className="mt-1 w-full rounded-xl border border-slate-700 bg-slate-900/80 px-3 py-2 text-[12px] text-slate-100 focus:outline-none focus:ring-2 focus:ring-emerald-500/60 focus:border-emerald-400"
                />
                <p className="mt-1 text-[10px] text-slate-500">
                  Used for reminders and upcoming-due panels later.
                </p>
              </div>
            </div>

            <div className="flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={handleStart}
                disabled={submitting || templates.length === 0}
                className="inline-flex items-center gap-2 rounded-full bg-emerald-500 px-4 py-2 text-[12px] font-semibold text-slate-950 shadow-md shadow-emerald-500/40 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-default"
              >
                {submitting ? "Starting…" : "Start assessment"}
              </button>
            </div>
          </div>
        </div>
      </section>
    </div>
  );
}
