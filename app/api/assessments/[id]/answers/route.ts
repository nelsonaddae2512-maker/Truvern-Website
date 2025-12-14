// app/api/assessments/[id]/answers/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { recalculateAssessmentScore } from "@/lib/scoring";

type RouteParams = {
  params: { id: string };
};

type IncomingAnswer = {
  questionId: number;
  value: string;
};

export async function POST(req: Request, { params }: RouteParams) {
  const assessmentId = Number(params.id);
  if (!assessmentId || Number.isNaN(assessmentId)) {
    return NextResponse.json(
      { error: "Invalid assessment id" },
      { status: 400 }
    );
  }

  let body: { answers: IncomingAnswer[]; markComplete?: boolean };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid JSON body" },
      { status: 400 }
    );
  }

  const { answers, markComplete = false } = body;
  if (!Array.isArray(answers) || answers.length === 0) {
    return NextResponse.json(
      { error: "No answers provided" },
      { status: 400 }
    );
  }

  try {
    await prisma.$transaction(async (tx) => {
      // Ensure assessment exists
      const assessment = await tx.assessment.findUnique({
        where: { id: assessmentId },
        select: { id: true },
      });

      if (!assessment) {
        throw new Error("Assessment not found");
      }

      // Upsert answers (AssessmentAnswer has @@unique([assessmentId, questionId]))
      for (const a of answers) {
        const qId = Number(a.questionId);
        if (!qId || Number.isNaN(qId)) continue;

        const value = (a.value ?? "").toString();

        await tx.assessmentAnswer.upsert({
          where: {
            assessmentId_questionId: {
              assessmentId,
              questionId: qId,
            },
          },
          update: {
            value,
          },
          create: {
            assessmentId,
            questionId: qId,
            value,
          },
        });
      }

      // Optionally mark as completed
      if (markComplete) {
        await tx.assessment.update({
          where: { id: assessmentId },
          data: {
            status: "COMPLETED",
            completedAt: new Date(),
          },
        });
      }
    });

    // After saving, recalc scores
    const result = await recalculateAssessmentScore(assessmentId);

    return NextResponse.json(
      {
        ok: true,
        assessmentId: result.assessmentId,
        score: result.score,
        confidentialityScore: result.confidentialityScore,
        integrityScore: result.integrityScore,
        availabilityScore: result.availabilityScore,
      },
      { status: 200 }
    );
  } catch (err) {
    console.error("Error saving assessment answers", err);
    return NextResponse.json(
      { error: "Failed to save answers" },
      { status: 500 }
    );
  }
}
