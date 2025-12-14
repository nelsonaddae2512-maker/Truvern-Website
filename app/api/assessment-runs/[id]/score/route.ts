import { NextRequest, NextResponse } from "next/server";
import * as prismaModule from "@/lib/prisma";

function prismaClient(): any {
  return (prismaModule as any).default ?? (prismaModule as any).prisma ?? prismaModule;
}

function scoreFromAnswerValue(v: any): number {
  if (v == null) return 0;
  const s = String(v).trim().toLowerCase();
  if (s === "yes" || s === "true") return 100;
  if (s === "no" || s === "false") return 0;

  const n = Number(v);
  if (Number.isFinite(n)) {
    if (n >= 0 && n <= 100) return n;
    if (n >= 1 && n <= 5) return ((n - 1) / 4) * 100;
  }
  return 0;
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const assessmentId = Number(id);
    if (!Number.isFinite(assessmentId)) {
      return NextResponse.json({ ok: false, error: "Invalid assessment id" }, { status: 400 });
    }

    const prisma = prismaClient();

    const assessment = await prisma.assessment.findUnique({ where: { id: assessmentId } });
    if (!assessment) {
      return NextResponse.json({ ok: false, error: "Assessment not found" }, { status: 404 });
    }

    const answers = await prisma.assessmentAnswer.findMany({
      where: { assessmentId },
      orderBy: { id: "asc" },
    });

    const qIds = Array.from(
      new Set(
        (answers as any[])
          .map((a) => a.questionId ?? a.assessmentQuestionId ?? a.qId ?? null)
          .filter(Boolean)
          .map((x) => Number(x))
          .filter((n) => Number.isFinite(n))
      )
    );

    const questions = qIds.length
      ? await prisma.assessmentQuestion.findMany({ where: { id: { in: qIds } } })
      : [];

    const qMap = new Map<number, any>();
    for (const q of questions as any[]) qMap.set(Number(q.id), q);

    let totalW = 0;
    let sum = 0;

    for (const a of answers as any[]) {
      const qid = a.questionId ?? a.assessmentQuestionId ?? a.qId ?? null;
      const q = qid ? qMap.get(Number(qid)) : null;

      const wRaw = q?.weight ?? q?.points ?? 1;
      const w = typeof wRaw === "number" && Number.isFinite(wRaw) ? wRaw : 1;

      const value = a.value ?? a.answer ?? a.text ?? a.response ?? null;
      const s = scoreFromAnswerValue(value);

      totalW += w;
      sum += s * w;
    }

    const computed = totalW > 0 ? sum / totalW : 0;

    // Write back to whichever field exists
    // Try score -> overallScore -> computedScore
    const updated = await prisma.assessment
      .update({
        where: { id: assessmentId },
        data: { score: computed } as any,
      })
      .catch(async () => {
        return prisma.assessment.update({
          where: { id: assessmentId },
          data: { overallScore: computed } as any,
        });
      })
      .catch(async () => {
        return prisma.assessment.update({
          where: { id: assessmentId },
          data: { computedScore: computed } as any,
        });
      });

    const url = new URL(req.url);
    return NextResponse.redirect(new URL(`/assessment/runs/${assessmentId}`, url.origin));
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message ?? "Unknown error" }, { status: 500 });
  }
}