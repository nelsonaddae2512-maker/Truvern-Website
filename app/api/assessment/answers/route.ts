// app/api/assessment/answers/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { resolveVendorContext } from "@/lib/auth/resolveVendorContext";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type SaveOne = { questionId: number; value: any };
type SaveBody =
  | { assessmentId: number; questionId: number; value: any }
  | { assessmentId: number; answers: SaveOne[] };

function badRequest(msg: string) {
  return NextResponse.json({ ok: false, error: msg }, { status: 400 });
}

export async function POST(req: NextRequest) {
  try {
    const ctx = await resolveVendorContext();
    if (!ctx) {
      return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
    }

    const body = (await req.json().catch(() => null)) as SaveBody | null;
    if (!body) return badRequest("Missing JSON body.");

    const assessmentId = Number((body as any).assessmentId);
    if (!Number.isFinite(assessmentId)) return badRequest("Invalid assessmentId.");

    // Load assessment + vendor binding (so we can authorize vendor users)
    const assessment = await prisma.assessment.findUnique({
      where: { id: assessmentId },
      select: {
        id: true,
        vendorId: true,
        status: true,
        templateId: true,
      },
    });

    if (!assessment) {
      return NextResponse.json({ ok: false, error: "Assessment not found." }, { status: 404 });
    }

    // Authorization:
    // - internal: always allowed
    // - bypass: allowed if vendor matches
    // - vendor: must match assessment.vendorId
    if (ctx.kind === "bypass" || ctx.kind === "vendor") {
      if (assessment.vendorId !== ctx.vendorId) {
        return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
      }
    }

    // Normalize payload to list of answers
    const incoming: SaveOne[] =
      "answers" in body
        ? (body.answers ?? [])
        : [{ questionId: Number((body as any).questionId), value: (body as any).value }];

    const cleaned = incoming
      .map((a) => ({
        questionId: Number(a.questionId),
        value: a.value,
      }))
      .filter((a) => Number.isFinite(a.questionId));

    if (cleaned.length === 0) return badRequest("No valid answers provided.");

    // Upsert answers (requires a unique constraint on (assessmentId, questionId))
    // If your schema uses different names, tell me and I’ll adjust.
    const saved = await prisma.$transaction(async (tx) => {
      const rows = [];
      for (const a of cleaned) {
        const row = await tx.assessmentAnswer.upsert({
          where: {
            assessmentId_questionId: {
              assessmentId,
              questionId: a.questionId,
            },
          },
          create: {
            assessmentId,
            questionId: a.questionId,
            value: a.value,
          },
          update: {
            value: a.value,
            updatedAt: new Date(),
          },
        });
        rows.push(row);
      }
      return rows;
    });

    // Progress stats (server truth)
    const totalQuestions = await prisma.assessmentQuestion.count({
      where: { templateId: assessment.templateId },
    });

    const answeredCount = await prisma.assessmentAnswer.count({
      where: {
        assessmentId,
        // treat null/empty as unanswered
        NOT: [{ value: null }],
      },
    });

    // Optional: auto-complete if all answered (only if there ARE questions)
    const shouldComplete = totalQuestions > 0 && answeredCount >= totalQuestions;

    const updatedAssessment = await prisma.assessment.update({
      where: { id: assessmentId },
      data: {
        status: shouldComplete ? "COMPLETED" : assessment.status,
        updatedAt: new Date(),
      },
      select: { id: true, status: true, updatedAt: true },
    });

    return NextResponse.json({
      ok: true,
      assessment: updatedAssessment,
      savedCount: saved.length,
      progress: {
        total: totalQuestions,
        answered: answeredCount,
      },
      saved,
    });
  } catch (err: any) {
    console.error("POST /api/assessment/answers error:", err);
    return NextResponse.json(
      { ok: false, error: "Server error." },
      { status: 500 }
    );
  }
}
