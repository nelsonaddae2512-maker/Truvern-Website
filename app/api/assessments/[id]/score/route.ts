// app/api/assessments/[id]/score/route.ts
import { NextResponse } from "next/server";
import { recalculateAssessmentScore } from "@/lib/scoring";

type RouteParams = {
  params: { id: string };
};

export async function POST(_req: Request, { params }: RouteParams) {
  const id = Number(params.id);
  if (!id || Number.isNaN(id)) {
    return NextResponse.json({ error: "Invalid assessment id" }, { status: 400 });
  }

  try {
    const result = await recalculateAssessmentScore(id);
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
    console.error("Error recalculating assessment score", err);
    return NextResponse.json(
      { error: "Failed to recalculate assessment score" },
      { status: 500 }
    );
  }
}
