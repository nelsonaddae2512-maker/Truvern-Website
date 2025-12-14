"use client";

import { useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";

type TemplateSection = {
  id: number;
  title: string;
  description: string | null;
  order: number;
  weight: number | null;
};

type TemplateQuestion = {
  id: number;
  text: string;
  description: string | null;
  helpText: string | null;
  category: string | null;
  type: string;
  sectionId: number | null;
  orderIndex: number;
  required: boolean;
  weight: number | null;
  createdAt: string;
  updatedAt: string;
};

type TemplateDetail = {
  id: number;
  name: string;
  description: string | null;
  standard: string | null;
  code: string | null;
  category: string | null;
  version: string | null;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
  sections: TemplateSection[];
  questions: TemplateQuestion[];
};

type State = "idle" | "loading" | "saving" | "error";

export default function TemplateBuilderPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const templateId = Number(params.id);

  const [state, setState] = useState<State>("loading");
  const [error, setError] = useState<string | null>(null);
  const [template, setTemplate] = useState<TemplateDetail | null>(null);

  const [newSectionTitle, setNewSectionTitle] = useState("");
  const [newSectionDescription, setNewSectionDescription] =
    useState("");

  useEffect(() => {
    if (!templateId || Number.isNaN(templateId)) return;

    let cancelled = false;

    async function load() {
      setState("loading");
      setError(null);
      try {
        const res = await fetch(
          `/api/assessment/templates/${templateId}`
        );
        if (!res.ok) {
          throw new Error(
            `Failed to load template (${res.status})`
          );
        }
        const data = (await res.json()) as TemplateDetail;
        if (!cancelled) {
          setTemplate(data);
          setState("idle");
        }
      } catch (err: any) {
        if (!cancelled) {
          setError(
            err?.message ?? "Failed to load template builder"
          );
          setState("error");
        }
      }
    }

    load();
    return () => {
      cancelled = true;
    };
  }, [templateId]);

  function formatDate(value: string) {
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return "";
    return d.toLocaleDateString(undefined, {
      year: "numeric",
      month: "short",
      day: "numeric",
    });
  }

  async function handleCreateSection(e: React.FormEvent) {
    e.preventDefault();
    if (!template || !newSectionTitle.trim()) return;

    setState("saving");
    setError(null);
    try {
      const res = await fetch(
        `/api/assessment/templates/${template.id}/sections`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            title: newSectionTitle.trim(),
            description:
              newSectionDescription.trim() || null,
          }),
        }
      );
      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(
          body?.error ?? "Failed to create section"
        );
      }
      const section = (await res.json()) as TemplateSection;
      setTemplate((prev) =>
        prev
          ? {
              ...prev,
              sections: [...prev.sections, section].sort(
                (a, b) => a.order - b.order
              ),
            }
          : prev
      );
      setNewSectionTitle("");
      setNewSectionDescription("");
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to create section");
      setState("error");
    }
  }

  async function handleAddQuestion(sectionId: number | null) {
    if (!template) return;
    const text = window.prompt(
      "New question text for this template:"
    );
    if (!text || !text.trim()) return;

    setState("saving");
    setError(null);

    try {
      const res = await fetch("/api/assessment/questions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          text: text.trim(),
          description: null,
          type: "YES_NO",
          category: sectionId ? null : template.category,
          templateId: template.id,
          sectionId,
        }),
      });

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(
          body?.error ?? "Failed to create question"
        );
      }

      const question = (await res.json()) as TemplateQuestion;

      setTemplate((prev) =>
        prev
          ? {
              ...prev,
              questions: [...prev.questions, question].sort(
                (a, b) => a.orderIndex - b.orderIndex
              ),
            }
          : prev
      );
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to create question");
      setState("error");
    }
  }

  async function handleDetachQuestion(question: TemplateQuestion) {
    if (
      !window.confirm(
        "Remove this question from the template? The question will remain in the global question bank."
      )
    ) {
      return;
    }

    setState("saving");
    setError(null);

    try {
      const res = await fetch(
        `/api/assessment/questions/${question.id}`,
        {
          method: "PATCH",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            text: question.text,
            description: question.description,
            type: question.type,
            category: question.category,
            templateId: null,
            sectionId: null,
          }),
        }
      );

      if (!res.ok) {
        const body = await res.json().catch(() => null);
        throw new Error(
          body?.error ?? "Failed to detach question"
        );
      }

      setTemplate((prev) =>
        prev
          ? {
              ...prev,
              questions: prev.questions.filter(
                (q) => q.id !== question.id
              ),
            }
          : prev
      );
      setState("idle");
    } catch (err: any) {
      setError(err?.message ?? "Failed to detach question");
      setState("error");
    }
  }

  if (!template) {
    return (
      <div className="mx-auto max-w-7xl px-6 py-6 text-sm text-slate-300">
        {state === "error"
          ? error ?? "Failed to load template"
          : "Loading template…"}
      </div>
    );
  }

  const sectionsById: Record<number, TemplateSection> = {};
  template.sections.forEach((s) => {
    sectionsById[s.id] = s;
  });

  const questionsBySection: Record<
    string,
    TemplateQuestion[]
  > = {};
  template.questions.forEach((q) => {
    const key = q.sectionId ? String(q.sectionId) : "unsectioned";
    if (!questionsBySection[key]) questionsBySection[key] = [];
    questionsBySection[key].push(q);
  });

  Object.keys(questionsBySection).forEach((key) => {
    questionsBySection[key].sort(
      (a, b) => a.orderIndex - b.orderIndex
    );
  });

  return (
    <div className="mx-auto max-w-7xl px-6 py-6 space-y-6">
      <button
        onClick={() => router.push("/assessment/templates")}
        className="text-xs text-emerald-300 hover:text-emerald-200 mb-2"
      >
        ← Back to templates
      </button>

      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-end sm:justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold text-slate-50 tracking-tight">
            Template builder
          </h1>
          <p className="mt-1 text-sm text-slate-400">
            Arrange sections and questions for{" "}
            <span className="font-semibold text-emerald-300">
              {template.name}
            </span>
            .
          </p>
        </div>
        <div className="text-xs text-slate-500 space-y-0.5 text-right">
          <div>
            Created:{" "}
            <span>{formatDate(template.createdAt)}</span>
          </div>
          <div>
            Updated:{" "}
            <span>{formatDate(template.updatedAt)}</span>
          </div>
        </div>
      </div>

      {error && (
        <div className="rounded-xl border border-rose-500/40 bg-rose-950/50 px-4 py-3 text-sm text-rose-100">
          {error}
        </div>
      )}

      {/* Sections + unsectioned */}
      <div className="space-y-6">
        {/* Unsectioned questions */}
        <div className="rounded-2xl border border-white/5 bg-slate-950/80 p-4 space-y-3">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-sm font-semibold text-slate-50">
                Unsectioned questions
              </h2>
              <p className="mt-1 text-xs text-slate-500">
                Questions without a section appear here. You can
                still use them in runs, but grouping by section is
                recommended.
              </p>
            </div>
            <button
              type="button"
              onClick={() => handleAddQuestion(null)}
              className="rounded-md bg-emerald-500/80 px-3 py-1.5 text-xs font-medium text-slate-950 hover:bg-emerald-400 transition"
              disabled={state === "saving"}
            >
              Add question
            </button>
          </div>

          <div className="mt-3 space-y-2">
            {(questionsBySection["unsectioned"] ?? []).map(
              (q) => (
                <div
                  key={q.id}
                  className="rounded-xl border border-slate-800 bg-slate-950/80 px-3 py-2 flex items-start justify-between gap-3"
                >
                  <div className="flex-1">
                    <div className="text-sm text-slate-50">
                      {q.text}
                    </div>
                    {q.description && (
                      <div className="mt-1 text-xs text-slate-400">
                        {q.description}
                      </div>
                    )}
                    <div className="mt-2 flex flex-wrap gap-2 text-[11px] text-slate-400">
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
                  <div className="flex flex-col items-end gap-2">
                    <button
                      type="button"
                      onClick={() => handleDetachQuestion(q)}
                      className="rounded-md border border-slate-700 px-2 py-1 text-[11px] text-slate-300 hover:bg-slate-900"
                      disabled={state === "saving"}
                    >
                      Remove from template
                    </button>
                  </div>
                </div>
              )
            )}

            {(questionsBySection["unsectioned"] ?? []).length ===
              0 && (
              <div className="text-xs text-slate-500">
                No unsectioned questions yet.
              </div>
            )}
          </div>
        </div>

        {/* Sections */}
        <div className="space-y-4">
          {template.sections
            .slice()
            .sort((a, b) => a.order - b.order)
            .map((section) => (
              <div
                key={section.id}
                className="rounded-2xl border border-white/5 bg-slate-950/80 p-4 space-y-3"
              >
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <h2 className="text-sm font-semibold text-slate-50">
                      {section.title}
                    </h2>
                    {section.description && (
                      <p className="mt-1 text-xs text-slate-500">
                        {section.description}
                      </p>
                    )}
                  </div>
                  <button
                    type="button"
                    onClick={() => handleAddQuestion(section.id)}
                    className="rounded-md bg-emerald-500/80 px-3 py-1.5 text-xs font-medium text-slate-950 hover:bg-emerald-400 transition"
                    disabled={state === "saving"}
                  >
                    Add question
                  </button>
                </div>

                <div className="space-y-2">
                  {(questionsBySection[String(section.id)] ??
                    []
                  ).map((q) => (
                    <div
                      key={q.id}
                      className="rounded-xl border border-slate-800 bg-slate-950/80 px-3 py-2 flex items-start justify-between gap-3"
                    >
                      <div className="flex-1">
                        <div className="text-sm text-slate-50">
                          {q.text}
                        </div>
                        {q.description && (
                          <div className="mt-1 text-xs text-slate-400">
                            {q.description}
                          </div>
                        )}
                        <div className="mt-2 flex flex-wrap gap-2 text-[11px] text-slate-400">
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
                      <div className="flex flex-col items-end gap-2">
                        <button
                          type="button"
                          onClick={() =>
                            handleDetachQuestion(q)
                          }
                          className="rounded-md border border-slate-700 px-2 py-1 text-[11px] text-slate-300 hover:bg-slate-900"
                          disabled={state === "saving"}
                        >
                          Remove from template
                        </button>
                      </div>
                    </div>
                  ))}

                  {(
                    questionsBySection[String(section.id)] ?? []
                  ).length === 0 && (
                    <div className="text-xs text-slate-500">
                      No questions in this section yet.
                    </div>
                  )}
                </div>
              </div>
            ))}
        </div>

        {/* New section form */}
        <form
          onSubmit={handleCreateSection}
          className="rounded-2xl border border-emerald-500/20 bg-slate-950/80 p-4 space-y-3"
        >
          <h2 className="text-sm font-semibold text-slate-50">
            Add section
          </h2>
          <div className="grid grid-cols-1 md:grid-cols-[minmax(0,1.4fr)_minmax(0,2fr)] gap-3">
            <div>
              <label className="text-xs font-medium text-slate-300">
                Section title
              </label>
              <input
                type="text"
                value={newSectionTitle}
                onChange={(e) =>
                  setNewSectionTitle(e.target.value)
                }
                placeholder="e.g. Security controls"
                className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
              />
            </div>
            <div>
              <label className="text-xs font-medium text-slate-300">
                Description (optional)
              </label>
              <textarea
                rows={2}
                value={newSectionDescription}
                onChange={(e) =>
                  setNewSectionDescription(e.target.value)
                }
                placeholder="Short description of what this section covers."
                className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm text-slate-50 outline-none focus:border-emerald-500 focus:ring-1 focus:ring-emerald-500/60"
              />
            </div>
          </div>
          <div className="flex justify-end">
            <button
              type="submit"
              disabled={
                !newSectionTitle.trim() || state === "saving"
              }
              className="rounded-md bg-emerald-500/80 px-4 py-2 text-sm font-medium text-slate-950 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-not-allowed transition"
            >
              Add section
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
