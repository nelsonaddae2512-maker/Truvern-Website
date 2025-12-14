"use client";

import { useEffect, useMemo, useRef, useState } from "react";

type Question = {
  id: number;
  text?: string | null;
  title?: string | null;
  prompt?: string | null;
  type?: string | null; // BOOLEAN | YES_NO | TEXT | ...
  points?: number | null;
  weight?: number | null;
  orderIndex?: number | null;
  order?: number | null;
};

type AnswerRow = {
  id: number;
  questionId: number | null;
  value?: any;
  updatedAt?: string | null;
};

type Props = {
  assessmentId: number;
  questions: Question[];
  initialAnswers: AnswerRow[];
};

function qLabel(q: Question) {
  return q.text ?? q.prompt ?? q.title ?? `Question #${q.id}`;
}

function qType(q: Question) {
  return String(q.type ?? "").toUpperCase();
}

function sortKey(q: Question) {
  const oi = typeof q.orderIndex === "number" ? q.orderIndex : null;
  if (oi != null && Number.isFinite(oi)) return oi;
  const o = typeof q.order === "number" ? q.order : null;
  if (o != null && Number.isFinite(o)) return o;
  return 9999;
}

function normalizeBoolean(v: any): boolean | null {
  if (v === true || v === false) return v;
  if (v == null) return null;
  const s = String(v).toLowerCase().trim();
  if (["yes", "true", "1"].includes(s)) return true;
  if (["no", "false", "0"].includes(s)) return false;
  return null;
}

export default function AssessmentRunResponder({ assessmentId, questions, initialAnswers }: Props) {
  const sorted = useMemo(() => [...questions].sort((a, b) => sortKey(a) - sortKey(b)), [questions]);

  const initialMap = useMemo(() => {
    const m = new Map<number, any>();
    for (const a of initialAnswers || []) {
      const qid = Number(a?.questionId);
      if (Number.isFinite(qid)) m.set(qid, a?.value);
    }
    return m;
  }, [initialAnswers]);

  const [values, setValues] = useState<Record<number, any>>(() => {
    const obj: Record<number, any> = {};
    for (const q of sorted) {
      const v = initialMap.get(q.id);
      if (v !== undefined) obj[q.id] = v;
    }
    return obj;
  });

  const [saving, setSaving] = useState(false);
  const [saveMsg, setSaveMsg] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const dirtyRef = useRef<Set<number>>(new Set());
  const timerRef = useRef<any>(null);

  const answeredCount = useMemo(() => {
    let c = 0;
    for (const q of sorted) {
      const v = values[q.id];
      const t = qType(q);
      if (t === "TEXT") {
        if (typeof v === "string" && v.trim().length > 0) c++;
      } else {
        if (normalizeBoolean(v) !== null) c++;
      }
    }
    return c;
  }, [sorted, values]);

  const score = useMemo(() => {
    let possible = 0;
    let earned = 0;

    for (const q of sorted) {
      const pts = typeof q.points === "number" && Number.isFinite(q.points) ? q.points : 0;
      possible += pts;

      const t = qType(q);
      const v = values[q.id];

      if (t === "TEXT") {
        // if text provided, award full points (simple default)
        if (typeof v === "string" && v.trim().length > 0) earned += pts;
      } else {
        // boolean/yes-no: true earns points, false earns 0
        const b = normalizeBoolean(v);
        if (b === true) earned += pts;
      }
    }

    const pct = possible > 0 ? Math.round((earned / possible) * 100) : 0;
    return { earned, possible, pct };
  }, [sorted, values]);

  async function flushSave(forceAll = false) {
    const dirty = dirtyRef.current;
    const toSave = forceAll ? sorted.map((q) => q.id) : Array.from(dirty);

    if (toSave.length === 0) return;

    setSaving(true);
    setError(null);
    setSaveMsg(null);

    try {
      const payload = {
        assessmentId,
        answers: toSave.map((qid) => ({
          questionId: qid,
          value: values[qid],
        })),
      };

      const res = await fetch("/api/assessment/answers", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      if (!res.ok) {
        const j = await res.json().catch(() => ({}));
        throw new Error(j?.error || `Save failed (${res.status})`);
      }

      dirty.clear();
      setSaveMsg("Saved");
    } catch (e: any) {
      setError(String(e?.message ?? e));
    } finally {
      setSaving(false);
      // clear the "Saved" message after a moment
      window.setTimeout(() => setSaveMsg(null), 1500);
    }
  }

  function scheduleAutosave() {
    if (timerRef.current) clearTimeout(timerRef.current);
    timerRef.current = setTimeout(() => flushSave(false), 650);
  }

  useEffect(() => {
    return () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    };
  }, []);

  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-5">
      <div className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="text-sm font-semibold text-slate-50">Questions</div>
          <div className="mt-1 text-xs text-slate-200/60">
            Progress: <span className="font-semibold text-slate-50">{answeredCount}/{sorted.length}</span>{" "}
            · Score: <span className="font-semibold text-slate-50">{score.earned}/{score.possible}</span>{" "}
            {score.possible ? <span className="opacity-80">({score.pct}%)</span> : null}
          </div>
        </div>

        <div className="flex items-center gap-2">
          {error ? <span className="text-xs text-rose-200">{error}</span> : null}
          {saveMsg ? <span className="text-xs text-emerald-200">{saveMsg}</span> : null}
          <button
            onClick={() => flushSave(true)}
            disabled={saving}
            className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10 disabled:opacity-60"
          >
            {saving ? "Saving…" : "Save"}
          </button>
        </div>
      </div>

      <div className="mt-4 space-y-3">
        {sorted.map((q, idx) => {
          const t = qType(q);
          const qid = q.id;
          const v = values[qid];

          return (
            <div key={qid} className="rounded-xl border border-white/10 bg-black/20 p-4">
              <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                  <div className="text-xs font-semibold text-slate-200/60">
                    Q{idx + 1} · {t || "—"} {typeof q.points === "number" ? `· ${q.points} pts` : ""}
                  </div>
                  <div className="mt-1 text-sm font-semibold text-slate-50">{qLabel(q)}</div>
                </div>

                <div className="shrink-0">
                  {t === "TEXT" ? (
                    typeof v === "string" && v.trim().length > 0 ? (
                      <span className="inline-flex items-center rounded-full border border-emerald-500/30 bg-emerald-500/10 px-2.5 py-1 text-[11px] font-semibold text-emerald-200">
                        Answered
                      </span>
                    ) : (
                      <span className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] font-semibold text-slate-200/70">
                        Unanswered
                      </span>
                    )
                  ) : normalizeBoolean(v) !== null ? (
                    <span className="inline-flex items-center rounded-full border border-emerald-500/30 bg-emerald-500/10 px-2.5 py-1 text-[11px] font-semibold text-emerald-200">
                      Answered
                    </span>
                  ) : (
                    <span className="inline-flex items-center rounded-full border border-white/10 bg-white/5 px-2.5 py-1 text-[11px] font-semibold text-slate-200/70">
                      Unanswered
                    </span>
                  )}
                </div>
              </div>

              <div className="mt-3">
                {(t === "BOOLEAN" || t === "YES_NO") && (
                  <div className="flex flex-wrap gap-2">
                    <button
                      type="button"
                      onClick={() => {
                        setValues((prev) => ({ ...prev, [qid]: true }));
                        dirtyRef.current.add(qid);
                        scheduleAutosave();
                      }}
                      className={
                        "rounded-lg border px-3 py-2 text-sm font-semibold " +
                        (normalizeBoolean(v) === true
                          ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-200"
                          : "border-white/10 bg-white/5 text-slate-50 hover:bg-white/10")
                      }
                    >
                      Yes
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setValues((prev) => ({ ...prev, [qid]: false }));
                        dirtyRef.current.add(qid);
                        scheduleAutosave();
                      }}
                      className={
                        "rounded-lg border px-3 py-2 text-sm font-semibold " +
                        (normalizeBoolean(v) === false
                          ? "border-amber-500/40 bg-amber-500/10 text-amber-200"
                          : "border-white/10 bg-white/5 text-slate-50 hover:bg-white/10")
                      }
                    >
                      No
                    </button>
                    <button
                      type="button"
                      onClick={() => {
                        setValues((prev) => {
                          const next = { ...prev };
                          delete next[qid];
                          return next;
                        });
                        dirtyRef.current.add(qid);
                        scheduleAutosave();
                      }}
                      className="rounded-lg border border-white/10 bg-white/5 px-3 py-2 text-sm font-semibold text-slate-50 hover:bg-white/10"
                    >
                      Clear
                    </button>
                  </div>
                )}

                {t === "TEXT" && (
                  <textarea
                    value={typeof v === "string" ? v : ""}
                    onChange={(e) => {
                      const next = e.target.value;
                      setValues((prev) => ({ ...prev, [qid]: next }));
                      dirtyRef.current.add(qid);
                      scheduleAutosave();
                    }}
                    rows={4}
                    placeholder="Type your response…"
                    className="w-full rounded-xl border border-white/10 bg-black/20 p-3 text-sm text-slate-50 placeholder:text-slate-200/40 focus:outline-none focus:ring-2 focus:ring-emerald-500/30"
                  />
                )}

                {t !== "TEXT" && t !== "BOOLEAN" && t !== "YES_NO" && (
                  <div className="text-sm text-slate-200/60">
                    This question type isn’t interactive yet: <span className="font-semibold">{t || "UNKNOWN"}</span>
                  </div>
                )}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
