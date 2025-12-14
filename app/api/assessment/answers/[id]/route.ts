import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function getAnswerIdFromUrl(req: NextRequest): number | null {
  try {
    const url = new URL(req.url);
    const segments = url.pathname.split("/").filter(Boolean);
    const last = segments[segments.length - 1];
    const id = Number.parseInt(last, 10);
    if (Number.isNaN(id)) return null;
    return id;
  } catch {
    return null;
  }
}

// PATCH /api/assessment/answers/:id
// Body: { value?, valueJson?, riskImpact? }
export async function PATCH(req: NextRequest) {
  try {
    const id = getAnswerIdFromUrl(req);
    if (id === null) {
      return NextResponse.json({ error: "Invalid answer id" }, { status: 400 });
    }

    const body = await req.json();
    const data: any = {};

    if (typeof body.value === "string") {
      data.value = body.value;
    }

    // valueJson can be object/array/null
    if (body.valueJson !== undefined) {
      data.valueJson = body.valueJson;
    }

    if (body.riskImpact !== undefined) {
      if (body.riskImpact === null) data.riskImpact = null;
      else if (typeof body.riskImpact === "number") data.riskImpact = body.riskImpact;
    }

    // Also set updatedAt (your schema uses optional updatedAt)
    data.updatedAt = new Date();

    // Update the answer
    const updated = await prisma.assessmentAnswer.update({
      where: { id },
      data,
      select: {
        id: true,
        questionId: true,
        assessmentId: true,
        value: true,
        valueJson: true,
        riskImpact: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    // If run is still DRAFT, bump to IN_PROGRESS on first edit
    await prisma.assessment.updateMany({
      where: { id: updated.assessmentId, status: "DRAFT" },
      data: { status: "IN_PROGRESS" },
    });

    return NextResponse.json({
      ...updated,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt ? updated.updatedAt.toISOString() : null,
    });
  } catch (error) {
    console.error("Error saving answer:", error);
    return NextResponse.json({ error: "Failed to save answer" }, { status: 500 });
  }
}
