"use client";

import { useEffect, useState } from "react";

type AssessmentQuestion = {
  id: number;
  text: string;
  description: string | null;
  type: string;
  category: string | null;
  createdAt: string;
  updatedAt: string;
};

type State = "idle" | "loading" | "submitting" | "error";

const QUESTION_TYPES = [
  { value: "YES_NO", label: "Yes / No" },
  { value: "TEXT", label: "Free text" },
  { value: "NUMBER", label: "Numeric" },
  { value: "MULTIPLE_CHOICE", label: "Multiple choice" },
  { value: "FILE_UPLOAD", label: "Evidence / file upload" },
];

const CATEGORIES = [
  "General",
  "Security",
  "Privacy",
  "Compliance",
  "Business Continuity",
  "Vendor Management",
];

export default function AssessmentQuestionsPage() {
  const [questions, setQuestions] = useState<AssessmentQuestion[]>([]);
  const [state, setState] = useState<State>("idle");
  const [error, setError] = useState<string | null>(null);

  // new question form
  const [text, setText] = useState("");
  const [description, setDescription] = useState("");
  const [type, setType] = useState<string>("YES_NO");
  const [category, setCategory] = useState<string>("Security");

  // detail / edit
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [editText, setEditText] = useState("");
  const [editDescription, setEditDescription] = useState("");
  const [editType, setEditType] = useState<string>("YES_NO");
  const [editCategory, setEditCategory] = useState<string>("Security");

  const selectedQuestion =
    questions.find((q) => q.id === selectedId) ?? null;

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setState("loading");
      setError(null);
      try {
        const res = await fetch("/api/assessment/questions");
        if (!res.ok) {
          throw new Error(`Failed to load questions (${res.status})`);
        }
        const data = (await res.json()) as AssessmentQuestion[];
        if (!cancelled) {
          setQuestions(data);
          setState("idle");
        }
      } catch (err: any) {
        if (!cancelled) {
          setError(err?.message ?? "Failed to load questions");
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
    if (!text.trim()) return;

    setState("submitting");
    setError(null);

    try {
      const res = await fetch("/api/assessment/questions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: text.trim(),
          description: description.trim() || null,
          type,
          category: category || null,
        }),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(body?.error ?? "Failed to create question");
      }

      const created = (await res.json()) as AssessmentQuestion;
      setQuestions((prev) => [created, ...prev]);
      setText("");
      setDescription("");
      setType("YES_NO");
      setCategory("Security");
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to create question");
      setState("error");
    }
  }

  function startEdit(question: AssessmentQuestion) {
    setSelectedId(question.id);
    setEditText(question.text);
    setEditDescription(question.description ?? "");
    setEditType(question.type || "YES_NO");
    setEditCategory(question.category || "Security");
  }

  async function handleSaveEdit() {
    if (!selectedQuestion || !editText.trim()) return;

    setState("submitting");
    setError(null);

    try {
      const res = await fetch(
        `/api/assessment/questions/${selectedQuestion.id}`,
        {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            text: editText.trim(),
            description: editDescription.trim() || null,
            type: editType,
            category: editCategory || null,
          }),
        }
      );

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(body?.error ?? "Failed to update question");
      }

      const updated = (await res.json()) as AssessmentQuestion;
      setQuestions((prev) =>
        prev.map((q) => (q.id === updated.id ? updated : q))
      );
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to update question");
      setState("error");
    }
  }

  async function handleDelete(id: number) {
    const ok = window.confirm(
      "Delete this question? This cannot be undone."
    );
    if (!ok) return;

    setState("submitting");
    setError(null);

    try {
      const res = await fetch(`/api/assessment/questions/${id}`, {
        method: "DELETE",
      });

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(body?.error ?? "Failed to delete question");
      }

      setQuestions((prev) => prev.filter((q) => q.id !== id));
      if (selectedId === id) {
        setSelectedId(null);
      }
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to delete question");
      setState("error");
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
        <div>
          <h2 className="text-lg font-semibold text-slate-50">
            Question bank
          </h2>
        </div>

        <div className="text-xs text-slate-500">
          {state === "loading"
            ? "Loading questions..."
            : `${questions.length} question${
                questions.length === 1 ? "" : "s"
              }`}
        </div>
      </div>

      {/* Error banner */}
      {error && (
        <div className="rounded-xl border border-rose-500/40 bg-rose-950/50 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      )}

      {/* New question form */}
      <form
        onSubmit={handleCreate}
        className="rounded-2xl border border-emerald-500/20 bg-slate-950/80 px-4 py-4 space-y-3"
      >
        <div className="grid grid-cols-1 md:grid-cols-[minmax(0,2fr)_minmax(0,1fr)_minmax(0,1fr)] gap-3">
          <div>
            <label className="text-xs font-medium text-slate-300">
              Question text
            </label>
            <input
              type="text"
              value={text}
              onChange={(e) => setText(e.target.value)}
              placeholder="e.g. Do you maintain an up-to-date ISO 27001 certification?"
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-slate-300">
              Type
            </label>
            <select
              value={type}
              onChange={(e) => setType(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            >
              {QUESTION_TYPES.map((t) => (
                <option key={t.value} value={t.value}>
                  {t.label}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="text-xs font-medium text-slate-300">
              Category
            </label>
            <select
              value={category}
              onChange={(e) => setCategory(e.target.value)}
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            >
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </div>
        </div>

        <div className="flex flex-col sm:flex-row sm:items-center sm:gap-3 mt-2">
          <div className="flex-1">
            <label className="text-xs font-medium text-slate-300">
              Helper text / guidance (optional)
            </label>
            <textarea
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              rows={2}
              placeholder="Clarify how the vendor should answer or what evidence to provide."
              className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
            />
          </div>

          <div className="mt-3 sm:mt-7 flex sm:flex-col items-center gap-2 justify-end">
            <button
              type="submit"
              disabled={!text.trim() || state === "submitting"}
              className="rounded-md bg-emerald-500/80 px-4 py-2 text-sm font-medium text-slate-950 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-not-allowed transition"
            >
              {state === "submitting" ? "Saving…" : "Add question"}
            </button>
          </div>
        </div>
      </form>

      {/* Grid: question list + details */}
      <div className="grid grid-cols-1 lg:grid-cols-[minmax(0,2fr)_minmax(0,1.4fr)] gap-4">
        {/* Question list */}
        <div className="rounded-2xl border border-white/5 bg-slate-950/80 overflow-hidden">
          <div className="border-b border-white/5 px-4 py-3 text-xs uppercase tracking-wide text-slate-500 flex items-center justify-between">
            <span>Question library</span>
          </div>
          <div className="max-h-[420px] overflow-auto text-sm">
            {questions.length === 0 && (
              <div className="px-4 py-6 text-sm text-slate-400">
                No questions yet. Add your first control above.
              </div>
            )}

            {questions.map((q) => {
              const isSelected = q.id === selectedId;
              return (
                <button
                  key={q.id}
                  type="button"
                  onClick={() => startEdit(q)}
                  className={`flex w-full items-start justify-between gap-3 border-b border-slate-900 px-4 py-3 text-left hover:bg-slate-900/60 ${
                    isSelected ? "bg-slate-900/80" : ""
                  }`}
                >
                  <div className="flex-1">
                    <div className="flex items-center gap-2">
                      <span className="text-slate-50 font-medium">
                        {q.text}
                      </span>
                    </div>
                    {q.description && (
                      <p className="mt-1 line-clamp-2 text-xs text-slate-400">
                        {q.description}
                      </p>
                    )}
                    <div className="mt-2 flex flex-wrap items-center gap-2 text-[11px] text-slate-400">
                      {q.category && (
                        <span className="rounded-full border border-slate-700 px-2 py-0.5">
                          {q.category}
                        </span>
                      )}
                      <span className="rounded-full border border-slate-700 px-2 py-0.5">
                        {q.type}
                      </span>
                    </div>
                  </div>
                  <div className="flex flex-col items-end gap-1 text-[11px] text-slate-500">
                    <span>Created: {formatDate(q.createdAt)}</span>
                    <span>Updated: {formatDate(q.updatedAt)}</span>
                  </div>
                </button>
              );
            })}
          </div>
        </div>

        {/* Detail / edit panel */}
        <div className="rounded-2xl border border-white/5 bg-slate-950/80 px-4 py-4">
          {!selectedQuestion ? (
            <div className="h-full flex items-center justify-center text-sm text-slate-500 text-center">
              Select a question from the list to review or edit its details.
            </div>
          ) : (
            <div className="space-y-4">
              <div>
                <h3 className="text-sm font-semibold text-slate-50">
                  Question details
                </h3>
                <p className="mt-1 text-xs text-slate-500">
                  These settings will be reused across all templates and runs
                  where this question appears.
                </p>
              </div>

              <div className="space-y-3">
                <div>
                  <label className="text-xs font-medium text-slate-300">
                    Question text
                  </label>
                  <textarea
                    rows={2}
                    value={editText}
                    onChange={(e) => setEditText(e.target.value)}
                    className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-slate-300">
                    Helper text / guidance
                  </label>
                  <textarea
                    rows={3}
                    value={editDescription}
                    onChange={(e) => setEditDescription(e.target.value)}
                    className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
                  />
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="text-xs font-medium text-slate-300">
                      Type
                    </label>
                    <select
                      value={editType}
                      onChange={(e) => setEditType(e.target.value)}
                      className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
                    >
                      {QUESTION_TYPES.map((t) => (
                        <option key={t.value} value={t.value}>
                          {t.label}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="text-xs font-medium text-slate-300">
                      Category
                    </label>
                    <select
                      value={editCategory}
                      onChange={(e) => setEditCategory(e.target.value)}
                      className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
                    >
                      {CATEGORIES.map((c) => (
                        <option key={c} value={c}>
                          {c}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>

              <div className="flex items-center justify-between pt-2">
                <div className="text-xs text-slate-500 space-y-0.5">
                  <div>
                    Created: {formatDate(selectedQuestion.createdAt)}
                  </div>
                  <div>
                    Updated: {formatDate(selectedQuestion.updatedAt)}
                  </div>
                </div>

                <div className="flex items-center gap-2">
                  <button
                    type="button"
                    onClick={() => handleDelete(selectedQuestion.id)}
                    disabled={state === "submitting"}
                    className="rounded-md border border-rose-500/60 px-3 py-1.5 text-xs font-medium text-rose-200 hover:bg-rose-500/10 disabled:opacity-60 disabled:cursor-not-allowed transition"
                  >
                    Delete
                  </button>
                  <button
                    type="button"
                    onClick={handleSaveEdit}
                    disabled={!editText.trim() || state === "submitting"}
                    className="rounded-md bg-emerald-500/80 px-4 py-1.5 text-xs font-medium text-slate-950 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-not-allowed transition"
                  >
                    {state === "submitting" ? "Saving…" : "Save changes"}
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
