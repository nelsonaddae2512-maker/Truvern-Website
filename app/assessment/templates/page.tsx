"use client";

import { useEffect, useState } from "react";
import Link from "next/link";

type AssessmentTemplate = {
  id: number;
  name: string;
  description: string | null;
  createdAt: string;
  updatedAt: string;
};

type State = "idle" | "loading" | "submitting" | "error";

export default function AssessmentTemplatesPage() {
  const [templates, setTemplates] = useState<AssessmentTemplate[]>([]);
  const [state, setState] = useState<State>("idle");
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [selectedId, setSelectedId] = useState<number | null>(null);

  const [editName, setEditName] = useState("");
  const [editDescription, setEditDescription] = useState("");

  const selectedTemplate =
    templates.find((t) => t.id === selectedId) ?? null;

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setState("loading");
      setError(null);
      try {
        const res = await fetch("/api/assessment/templates");
        if (!res.ok) {
          throw new Error(
            `Failed to load templates (${res.status})`
          );
        }
        const data = (await res.json()) as AssessmentTemplate[];
        if (!cancelled) {
          setTemplates(data);
          setState("idle");
        }
      } catch (err: any) {
        if (!cancelled) {
          setError(err?.message ?? "Failed to load templates");
          setState("error");
        }
      }
    }

    load();

    return () => {
      cancelled = true;
    };
  }, []);

  function formatDate(value: string) {
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleDateString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;

    setState("submitting");
    setError(null);

    try {
      const res = await fetch("/api/assessment/templates", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: name.trim(),
          description: description.trim() || null,
        }),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(body?.error ?? "Failed to create template");
      }

      const created = (await res.json()) as AssessmentTemplate;
      setTemplates((prev) => [created, ...prev]);
      setName("");
      setDescription("");
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to create template");
      setState("error");
    }
  }

  function startEdit(template: AssessmentTemplate) {
    setSelectedId(template.id);
    setEditName(template.name);
    setEditDescription(template.description ?? "");
  }

  async function handleSaveEdit() {
    if (!selectedTemplate || !editName.trim()) return;

    setState("submitting");
    setError(null);

    try {
      const res = await fetch(
        `/api/assessment/templates/${selectedTemplate.id}`,
        {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            name: editName.trim(),
            description: editDescription.trim() || null,
          }),
        }
      );

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(body?.error ?? "Failed to update template");
      }

      const updated = (await res.json()) as AssessmentTemplate;
      setTemplates((prev) =>
        prev.map((t) => (t.id === updated.id ? updated : t))
      );
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to update template");
      setState("error");
    }
  }

  async function handleDelete(id: number) {
    const ok = window.confirm(
      "Delete this template? This cannot be undone."
    );
    if (!ok) return;

    setState("submitting");
    setError(null);

    try {
      const res = await fetch(`/api/assessment/templates/${id}`, {
        method: "DELETE",
      });

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(body?.error ?? "Failed to delete template");
      }

      setTemplates((prev) => prev.filter((t) => t.id !== id));
      if (selectedId === id) {
        setSelectedId(null);
      }
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to delete template");
      setState("error");
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-slate-50">
            Templates
          </h2>
          <p className="mt-1 text-sm text-slate-400">
            Reusable questionnaires you can run against vendors
            and map into the scoring engine.
          </p>
        </div>

        <div className="text-xs text-slate-500">
          {state === "loading"
            ? "Loading templates..."
            : `${templates.length} template${
                templates.length === 1 ? "" : "s"
              }`}
        </div>
      </div>

      {/* Error banner */}
      {error && (
        <div className="rounded-xl border border-rose-500/40 bg-rose-950/50 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      )}

      {/* New template form */}
      <form
        onSubmit={handleCreate}
        className="rounded-2xl border border-emerald-500/20 bg-slate-950/80 px-4 py-4 space-y-3"
      >
        <div className="flex flex-col sm:flex-row sm:items-center sm:gap-3">
          <div className="flex-1">
            <label className="text-xs font-medium text-slate-300">
              Template name
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Core Security Baseline v1.0"
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            />
          </div>
        </div>

        <div className="flex flex-col sm:flex-row sm:items-center sm:gap-3">
          <div className="flex-1">
            <label className="text-xs font-medium text-slate-300">
              Description
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              placeholder="Short description of what this assessment template covers."
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            />
          </div>

          <div className="mt-3 sm:mt-7 flex sm:flex-col items-center gap-2 justify-end">
            <button
              type="submit"
              disabled={!name.trim() || state === "submitting"}
              className="rounded-md bg-emerald-500/80 px-4 py-2 text-sm font-medium text-slate-950 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-not-allowed transition"
            >
              {state === "submitting" ? "Saving…" : "Add template"}
            </button>
          </div>
        </div>
      </form>

      {/* Grid layout: table + details */}
      <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,2fr)_minmax(0,1.3fr)] gap-4">
        {/* Template table */}
        <div className="rounded-2xl border border-white/5 bg-slate-950/80 overflow-hidden">
          <div className="border-b border-white/5 px-4 py-3 text-xs uppercase tracking-wide text-slate-500">
            Template library
          </div>
          <div className="max-h-[420px] overflow-auto text-sm">
            {templates.length === 0 && (
              <div className="px-4 py-6 text-sm text-slate-400">
                No templates yet. Create your first assessment
                template above.
              </div>
            )}

            {templates.map((t) => {
              const isSelected = t.id === selectedId;
              return (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => startEdit(t)}
                  className={`flex w-full items-start justify-between gap-3 border-b border-slate-900 px-4 py-3 text-left hover:bg-slate-900/60 ${
                    isSelected ? "bg-slate-900/80" : ""
                  }`}
                >
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="text-slate-50 font-medium">
                        {t.name}
                      </span>
                    </div>
                    {t.description && (
                      <p className="mt-1 line-clamp-2 text-xs text-slate-400">
                        {t.description}
                      </p>
                    )}
                  </div>
                  <div className="flex flex-col items-end gap-1 text-[11px] text-slate-500">
                    <span>
                      Created: {formatDate(t.createdAt)}
                    </span>
                    <span>
                      Updated: {formatDate(t.updatedAt)}
                    </span>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Details / edit panel */}
        <div className="rounded-2xl border border-white/5 bg-slate-950/80 px-4 py-4">
          {!selectedTemplate ? (
            <div className="h-full flex items-center justify-center text-sm text-slate-500 text-center">
              Select a template from the list to edit its
              metadata.
            </div>
          ) : (
            <div className="space-y-4">
              <div>
                <h3 className="text-sm font-semibold text-slate-50">
                  Template details
                </h3>
                <p className="mt-1 text-xs text-slate-500">
                  Name and description will show up anywhere
                  this template is referenced (runs, vendor
                  workspace, board report).
                </p>
              </div>

              <div className="space-y-3">
                <div>
                  <label className="text-xs font-medium text-slate-300">
                    Name
                  </label>
                  <input
                    type="text"
                    value={editName}
                    onChange={(e) =>
                      setEditName(e.target.value)
                    }
                    className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-slate-300">
                    Description
                  </label>
                  <textarea
                    rows={3}
                    value={editDescription}
                    onChange={(e) =>
                      setEditDescription(e.target.value)
                    }
                    className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
                  />
                </div>
              </div>

              <div className="flex items-center justify-between pt-2">
                <div className="text-xs text-slate-500 space-y-0.5">
                  <div>
                    Created:{" "}
                    {formatDate(selectedTemplate.createdAt)}
                  </div>
                  <div>
                    Updated:{" "}
                    {formatDate(selectedTemplate.updatedAt)}
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {/* New: open template builder */}
                  <Link
                    href={`/assessment/templates/${selectedTemplate.id}`}
                    className="rounded-md border border-emerald-500/60 px-3 py-1.5 text-xs font-medium text-emerald-300 hover:bg-emerald-500/10 transition"
                  >
                    Open builder
                  </Link>

                  <button
                    type="button"
                    onClick={() =>
                      handleDelete(selectedTemplate.id)
                    }
                    disabled={state === "submitting"}
                    className="rounded-md border border-rose-500/60 px-3 py-1.5 text-xs font-medium text-rose-200 hover:bg-rose-500/10 disabled:opacity-60 disabled:cursor-not-allowed transition"
                  >
                    Delete
                  </button>
                  <button
                    type="button"
                    onClick={handleSaveEdit}
                    disabled={
                      !editName.trim() || state === "submitting"
                    }
                    className="rounded-md bg-emerald-500/80 px-4 py-1.5 text-xs font-medium text-slate-950 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-not-allowed transition"
                  >
                    {state === "submitting"
                      ? "Saving…"
                      : "Save changes"}
                  </button>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
