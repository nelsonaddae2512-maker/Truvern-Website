"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

type RunStatus = "DRAFT" | "IN_PROGRESS" | "COMPLETED" | "ARCHIVED";

type AssessmentRunListItem = {
  id: number;
  title: string | null;
  status: RunStatus;
  vendorId: number;
  vendorName: string;
  templateId: number | null;
  templateName: string | null;
  createdAt: string;
  updatedAt: string;
  dueAt: string | null;
  completedAt: string | null;
};

type VendorOption = {
  id: number;
  name: string;
};

type TemplateOption = {
  id: number;
  name: string;
};

type State = "idle" | "loading" | "submitting" | "error";

export default function AssessmentRunsPage() {
  const [runs, setRuns] = useState<AssessmentRunListItem[]>([]);
  const [vendors, setVendors] = useState<VendorOption[]>([]);
  const [templates, setTemplates] = useState<TemplateOption[]>([]);

  const [state, setState] = useState<State>("loading");
  const [error, setError] = useState<string | null>(null);

  // Create-run form
  const [createVendorId, setCreateVendorId] = useState<number | "">("");
  const [createTemplateId, setCreateTemplateId] = useState<
    number | ""
  >("");
  const [createTitle, setCreateTitle] = useState("");

  // Filters
  const [filterStatus, setFilterStatus] = useState<RunStatus | "ALL">(
    "ALL"
  );

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setState("loading");
      setError(null);
      try {
        const [runsRes, optionsRes] = await Promise.all([
          fetch("/api/assessment/runs"),
          fetch("/api/assessment/runs/options"),
        ]);

        if (!runsRes.ok) {
          throw new Error(
            `Failed to load runs (${runsRes.status})`
          );
        }
        if (!optionsRes.ok) {
          throw new Error(
            `Failed to load options (${optionsRes.status})`
          );
        }

        const runsData =
          (await runsRes.json()) as AssessmentRunListItem[];
        const optionsData = (await optionsRes.json()) as {
          vendors: VendorOption[];
          templates: TemplateOption[];
        };

        if (!cancelled) {
          setRuns(runsData);
          setVendors(optionsData.vendors);
          setTemplates(optionsData.templates);
          setState("idle");
        }
      } catch (err: any) {
        if (!cancelled) {
          setError(
            err?.message ?? "Failed to load assessment runs"
          );
          setState("error");
        }
      }
    }

    load();

    return () => {
      cancelled = true;
    };
  }, []);

  function formatDate(value: string | null) {
    if (!value) return "";
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleDateString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  async function handleCreateRun(e: any) {
    e.preventDefault();
    if (!createVendorId || !createTemplateId) return;

    setState("submitting");
    setError(null);

    try {
      const res = await fetch("/api/assessment/runs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          vendorId: createVendorId,
          templateId: createTemplateId,
          title: createTitle.trim() || undefined,
        }),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(
          body?.error ?? "Failed to create assessment run"
        );
      }

      const created =
        (await res.json()) as AssessmentRunListItem;

      setRuns((prev) => [created, ...prev]);
      setCreateVendorId("");
      setCreateTemplateId("");
      setCreateTitle("");
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to create assessment run");
      setState("error");
    }
  }

  async function handleDeleteRun(id: number) {
    const ok = window.confirm(
      "Delete this run? This cannot be undone."
    );
    if (!ok) return;

    setState("submitting");
    setError(null);

    try {
      const res = await fetch(`/api/assessment/runs/${id}`, {
        method: "DELETE",
      });

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(
          body?.error ?? "Failed to delete assessment run"
        );
      }

      setRuns((prev) => prev.filter((r) => r.id !== id));
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to delete assessment run");
      setState("error");
    }
  }

  const filteredRuns =
    filterStatus === "ALL"
      ? runs
      : runs.filter((r) => r.status === filterStatus);

  const STATUS_OPTIONS: (RunStatus | "ALL")[] = [
    "ALL",
    "DRAFT",
    "IN_PROGRESS",
    "COMPLETED",
    "ARCHIVED",
  ];

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-slate-50">
            Assessment runs
          </h2>
          <p className="mt-1 text-sm text-slate-400">
            Live assessments generated from your templates and
            vendors. Drafts can be edited before you mark them
            completed.
          </p>
        </div>

        <div className="flex flex-col items-end gap-2">
          <div className="text-xs text-slate-500">
            {state === "loading"
              ? "Loading runs..."
              : `${runs.length} run${
                  runs.length === 1 ? "" : "s"
                }`}
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span className="text-slate-400">
              Filter status:
            </span>
            <select
              className="rounded-md border border-slate-700 bg-slate-950 px-2 py-1 text-xs text-slate-100"
              value={filterStatus}
              onChange={(e) =>
                setFilterStatus(
                  e.target.value as RunStatus | "ALL"
                )
              }
            >
              {STATUS_OPTIONS.map((s) => (
                <option key={s} value={s}>
                  {s === "ALL" ? "All statuses" : s}
                </option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Error banner */}
      {error && (
        <div className="rounded-xl border border-rose-500/40 bg-rose-950/50 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      )}

      {/* New run form */}
      <form
        onSubmit={handleCreateRun}
        className="rounded-2xl border border-emerald-500/20 bg-slate-950/80 px-4 py-4 space-y-3"
      >
        <div className="flex flex-col md:flex-row md:items-end md:gap-3">
          <div className="flex-1">
            <label className="text-xs font-medium text-slate-300">
              Vendor
            </label>
            <select
              value={createVendorId === "" ? "" : String(createVendorId)}
              onChange={(e) => {
                const val = e.target.value;
                setCreateVendorId(
                  val ? Number.parseInt(val, 10) : ""
                );
              }}
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            >
              <option value="">Select vendor…</option>
              {vendors.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.name}
                </option>
              ))}
            </select>
          </div>

          <div className="flex-1 mt-3 md:mt-0">
            <label className="text-xs font-medium text-slate-300">
              Template
            </label>
            <select
              value={
                createTemplateId === ""
                  ? ""
                  : String(createTemplateId)
              }
              onChange={(e) => {
                const val = e.target.value;
                setCreateTemplateId(
                  val ? Number.parseInt(val, 10) : ""
                );
              }}
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            >
              <option value="">Select template…</option>
              {templates.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
          </div>

          <div className="flex-1 mt-3 md:mt-0">
            <label className="text-xs font-medium text-slate-300">
              Title (optional)
            </label>
            <input
              type="text"
              value={createTitle}
              onChange={(e) => setCreateTitle(e.target.value)}
              placeholder="If left blank, a smart default will be used."
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            />
          </div>

          <div className="mt-3 md:mt-0 flex items-end">
            <button
              type="submit"
              disabled={
                !createVendorId ||
                !createTemplateId ||
                state === "submitting"
              }
              className="w-full md:w-auto rounded-md bg-emerald-500/80 px-4 py-2 text-sm font-medium text-slate-950 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-not-allowed transition"
            >
              {state === "submitting"
                ? "Creating…"
                : "Create run"}
            </button>
          </div>
        </div>
      </form>

      {/* Runs table */}
      <div className="rounded-2xl border border-white/5 bg-slate-950/80 overflow-hidden">
        <div className="border-b border-white/5 px-4 py-3 text-xs uppercase tracking-wide text-slate-500">
          Runs &amp; scores
        </div>
        <div className="max-h-[480px] overflow-auto text-sm">
          {filteredRuns.length === 0 && (
            <div className="px-4 py-6 text-sm text-slate-400">
              {runs.length === 0
                ? "No assessment runs yet. Create your first run above."
                : "No runs match the current filter."}
            </div>
          )}

          {filteredRuns.map((run) => (
            <div
              key={run.id}
              className="flex items-center justify-between gap-3 border-b border-slate-900 px-4 py-3"
            >
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <Link
                    href={`/assessment/runs/${run.id}`}
                    className="truncate text-slate-50 font-medium hover:text-emerald-300"
                  >
                    {run.title || "Untitled assessment"}
                  </Link>
                  <span className="text-[11px] rounded-full border border-slate-700 px-2 py-0.5 text-slate-300">
                    {run.vendorName}
                  </span>
                  {run.templateName && (
                    <span className="text-[11px] rounded-full border border-slate-700 px-2 py-0.5 text-slate-400">
                      {run.templateName}
                    </span>
                  )}
                </div>
                <div className="mt-1 flex flex-wrap items-center gap-3 text-[11px] text-slate-500">
                  <span>
                    Updated: {formatDate(run.updatedAt) || "–"}
                  </span>
                  {run.dueAt && (
                    <span>Due: {formatDate(run.dueAt)}</span>
                  )}
                  {run.completedAt && (
                    <span>
                      Completed: {formatDate(run.completedAt)}
                    </span>
                  )}
                </div>
              </div>

              <div className="flex items-center gap-2">
                <span
                  className={`text-[11px] rounded-full px-2 py-0.5 border ${
                    run.status === "COMPLETED"
                      ? "border-emerald-500/70 text-emerald-300"
                      : run.status === "IN_PROGRESS"
                      ? "border-amber-400/70 text-amber-300"
                      : run.status === "ARCHIVED"
                      ? "border-slate-500/70 text-slate-300"
                      : "border-slate-600/70 text-slate-300"
                  }`}
                >
                  {run.status}
                </span>
                <button
                  type="button"
                  onClick={() => handleDeleteRun(run.id)}
                  disabled={state === "submitting"}
                  className="text-[11px] rounded-md border border-rose-500/60 px-2 py-1 text-rose-200 hover:bg-rose-500/10 disabled:opacity-60 disabled:cursor-not-allowed transition"
                >
                  Delete
                </button>
                <Link
                  href={`/assessment/runs/${run.id}`}
                  className="text-[11px] rounded-md border border-emerald-500/60 px-2 py-1 text-emerald-300 hover:bg-emerald-500/10 transition"
                >
                  Open
                </Link>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
