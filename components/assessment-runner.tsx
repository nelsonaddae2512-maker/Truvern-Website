"use client";

import { useState } from "react";

type QuestionKind = "YES_NO" | "TEXT" | "SELECT" | "MULTI_SELECT" | "NUMBER";

type RunnerQuestion = {
  id: number;
  prompt: string;
  helpText?: string | null;
  kind: QuestionKind;
  required: boolean;
  key?: string | null;
  options: string[];
  existingValue: string;
};

type RunnerSection = {
  id: number;
  title: string;
  description?: string | null;
  order: number;
  questions: RunnerQuestion[];
};

type RunnerData = {
  assessmentId: number;
  vendorName: string;
  templateName: string;
  status: string;
  score: number | null;
  confidentialityScore: number | null;
  integrityScore: number | null;
  availabilityScore: number | null;
  sections: RunnerSection[];
};

type Props = {
  initialData: RunnerData;
};

export default function AssessmentRunner({ initialData }: Props) {
  const [answers, setAnswers] = useState<Record<number, string>>(() => {
    const record: Record<number, string> = {};
    for (const section of initialData.sections) {
      for (const q of section.questions) {
        record[q.id] = q.existingValue ?? "";
      }
    }
    return record;
  });

  const [saving, setSaving] = useState<"draft" | "complete" | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [lastSavedScores, setLastSavedScores] = useState<{
    score: number | null;
    confidentialityScore: number | null;
    integrityScore: number | null;
    availabilityScore: number | null;
  }>({
    score: initialData.score ?? null,
    confidentialityScore: initialData.confidentialityScore ?? null,
    integrityScore: initialData.integrityScore ?? null,
    availabilityScore: initialData.availabilityScore ?? null,
  });

  async function handleSave(markComplete: boolean) {
    try {
      setError(null);
      setSaving(markComplete ? "complete" : "draft");

      const payload = {
        markComplete,
        answers: Object.entries(answers).map(([questionId, value]) => ({
          questionId: Number(questionId),
          value,
        })),
      };

      const res = await fetch(
        `/api/assessments/${initialData.assessmentId}/answers`,
        {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(payload),
        }
      );

      if (!res.ok) {
        const data = await res.json().catch(() => null);
        throw new Error(data?.error || "Failed to save answers");
      }

      const data = await res.json();
      setLastSavedScores({
        score: data.score ?? null,
        confidentialityScore: data.confidentialityScore ?? null,
        integrityScore: data.integrityScore ?? null,
        availabilityScore: data.availabilityScore ?? null,
      });
    } catch (err: any) {
      console.error(err);
      setError(err.message ?? "Failed to save assessment");
    } finally {
      setSaving(null);
    }
  }

  function updateAnswer(questionId: number, value: string) {
    setAnswers((prev) => ({
      ...prev,
      [questionId]: value,
    }));
  }

  function scoreLabel(score: number | null) {
    if (score == null) return "Not scored yet";

    if (score >= 85) return `Strong (${score})`;
    if (score >= 70) return `Good (${score})`;
    if (score >= 50) return `Needs improvement (${score})`;
    return `Weak (${score})`;
  }

  function scoreTone(score: number | null) {
    if (score == null) return "text-slate-400";
    if (score >= 85) return "text-emerald-300";
    if (score >= 70) return "text-cyan-300";
    if (score >= 50) return "text-amber-300";
    return "text-rose-300";
  }

  return (
    <div className="space-y-6">
      {/* Header / summary card */}
      <section className="rounded-3xl border border-slate-800 bg-slate-950/80 px-4 py-4 shadow-lg shadow-black/40">
        <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
          <div className="space-y-2">
            <div className="inline-flex items-center gap-2 rounded-full bg-slate-900/70 border border-emerald-500/30 px-3 py-1">
              <span className="h-1.5 w-1.5 rounded-full bg-emerald-400 animate-pulse" />
              <span className="text-[10px] font-semibold tracking-[0.2em] text-emerald-300 uppercase">
                Assessment in progress
              </span>
            </div>
            <div>
              <h1 className="text-2xl font-semibold text-slate-50 tracking-tight">
                {initialData.templateName}
              </h1>
              <p className="text-sm text-slate-300">
                Vendor:{" "}
                <span className="font-medium text-emerald-300">
                  {initialData.vendorName}
                </span>
              </p>
              <p className="mt-1 text-[11px] text-slate-500">
                Answers here roll directly into vendor risk, portfolio
                dashboards, and your board report.
              </p>
            </div>
          </div>

          {/* Scores */}
          <div className="flex flex-col items-end gap-2">
            <div className="rounded-2xl border border-slate-700 bg-slate-900/70 px-3 py-2 text-right">
              <p className="text-[11px] text-slate-400">Overall score</p>
              <p
                className={
                  "text-sm font-semibold " + scoreTone(lastSavedScores.score)
                }
              >
                {scoreLabel(lastSavedScores.score)}
              </p>
            </div>
            <div className="flex gap-2 text-[10px]">
              <div className="rounded-xl border border-slate-700 bg-slate-900/70 px-2 py-1">
                <span className="text-slate-400 mr-1">C</span>
                <span className={scoreTone(lastSavedScores.confidentialityScore)}>
                  {lastSavedScores.confidentialityScore ?? "–"}
                </span>
              </div>
              <div className="rounded-xl border border-slate-700 bg-slate-900/70 px-2 py-1">
                <span className="text-slate-400 mr-1">I</span>
                <span className={scoreTone(lastSavedScores.integrityScore)}>
                  {lastSavedScores.integrityScore ?? "–"}
                </span>
              </div>
              <div className="rounded-xl border border-slate-700 bg-slate-900/70 px-2 py-1">
                <span className="text-slate-400 mr-1">A</span>
                <span className={scoreTone(lastSavedScores.availabilityScore)}>
                  {lastSavedScores.availabilityScore ?? "–"}
                </span>
              </div>
            </div>
          </div>
        </div>

        {error && (
          <div className="mt-3 rounded-2xl border border-rose-500/60 bg-rose-950/40 px-3 py-2 text-[11px] text-rose-100">
            {error}
          </div>
        )}
      </section>

      {/* Sections & questions */}
      <section className="rounded-3xl border border-slate-800 bg-slate-950/80 px-4 py-4 shadow-lg shadow-black/40">
        <div className="flex items-center justify-between mb-3">
          <div>
            <p className="text-[11px] font-semibold uppercase tracking-[0.18em] text-slate-400">
              Answer the questionnaire
            </p>
            <p className="text-[11px] text-slate-500">
              Respond as the vendor would; add context in free text where needed.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <button
              type="button"
              disabled={saving === "draft"}
              onClick={() => handleSave(false)}
              className="inline-flex items-center gap-2 rounded-full border border-slate-700 bg-slate-900/80 px-3 py-1.5 text-[11px] text-slate-200 hover:border-emerald-400 hover:text-emerald-200 disabled:opacity-60 disabled:cursor-default"
            >
              {saving === "draft" ? "Saving draft…" : "Save draft"}
            </button>
            <button
              type="button"
              disabled={saving === "complete"}
              onClick={() => handleSave(true)}
              className="inline-flex items-center gap-2 rounded-full bg-emerald-500 px-3 py-1.5 text-[11px] font-semibold text-slate-950 shadow-md shadow-emerald-500/40 hover:bg-emerald-400 disabled:opacity-60 disabled:cursor-default"
            >
              {saving === "complete" ? "Submitting…" : "Submit & score"}
            </button>
          </div>
        </div>

        <div className="space-y-4">
          {initialData.sections.map((section) => (
            <div
              key={section.id}
              className="rounded-2xl border border-slate-800 bg-slate-950/90 px-3 py-3"
            >
              <div className="mb-2">
                <h2 className="text-sm font-semibold text-slate-100">
                  {section.title}
                </h2>
                {section.description && (
                  <p className="text-[11px] text-slate-500">
                    {section.description}
                  </p>
                )}
              </div>

              <div className="space-y-3">
                {section.questions.map((q) => {
                  const value = answers[q.id] ?? "";

                  return (
                    <div
                      key={q.id}
                      className="rounded-xl border border-slate-800 bg-slate-950 px-3 py-2"
                    >
                      <div className="flex justify-between gap-3">
                        <div>
                          <p className="text-[13px] text-slate-100">
                            {q.prompt}
                            {q.required && (
                              <span className="text-rose-400 ml-1">*</span>
                            )}
                          </p>
                          {q.helpText && (
                            <p className="text-[11px] text-slate-500 mt-0.5">
                              {q.helpText}
                            </p>
                          )}
                        </div>
                        {q.key && (
                          <p className="text-[10px] text-slate-500">
                            <span className="rounded-full border border-slate-700 bg-slate-900/70 px-2 py-0.5">
                              {q.key}
                            </span>
                          </p>
                        )}
                      </div>

                      <div className="mt-2">
                        {q.kind === "YES_NO" ? (
                          <select
                            value={value}
                            onChange={(e) => updateAnswer(q.id, e.target.value)}
                            className="w-full rounded-lg border border-slate-700 bg-slate-900/80 px-2 py-1.5 text-[12px] text-slate-100 focus:outline-none focus:ring-1 focus:ring-emerald-500/60 focus:border-emerald-400"
                          >
                            <option value="">Select an answer</option>
                            <option value="Yes">Yes</option>
                            <option value="No">No</option>
                            <option value="N/A">N/A</option>
                          </select>
                        ) : q.kind === "NUMBER" ? (
                          <input
                            type="number"
                            value={value}
                            onChange={(e) => updateAnswer(q.id, e.target.value)}
                            className="w-full rounded-lg border border-slate-700 bg-slate-900/80 px-2 py-1.5 text-[12px] text-slate-100 focus:outline-none focus:ring-1 focus:ring-emerald-500/60 focus:border-emerald-400"
                            placeholder="Enter a numeric value"
                          />
                        ) : q.kind === "SELECT" ? (
                          <select
                            value={value}
                            onChange={(e) => updateAnswer(q.id, e.target.value)}
                            className="w-full rounded-lg border border-slate-700 bg-slate-900/80 px-2 py-1.5 text-[12px] text-slate-100 focus:outline-none focus:ring-1 focus:ring-emerald-500/60 focus:border-emerald-400"
                          >
                            <option value="">Select an option</option>
                            {q.options.map((opt) => (
                              <option key={opt} value={opt}>
                                {opt}
                              </option>
                            ))}
                          </select>
                        ) : q.kind === "MULTI_SELECT" ? (
                          <textarea
                            value={value}
                            onChange={(e) => updateAnswer(q.id, e.target.value)}
                            rows={2}
                            className="w-full rounded-lg border border-slate-700 bg-slate-900/80 px-2 py-1.5 text-[12px] text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-emerald-500/60 focus:border-emerald-400 resize-none"
                            placeholder="List selected options or describe your selection."
                          />
                        ) : (
                          // TEXT fallback
                          <textarea
                            value={value}
                            onChange={(e) => updateAnswer(q.id, e.target.value)}
                            rows={3}
                            className="w-full rounded-lg border border-slate-700 bg-slate-900/80 px-2 py-1.5 text-[12px] text-slate-100 placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-emerald-500/60 focus:border-emerald-400 resize-none"
                            placeholder="Type your response here."
                          />
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
