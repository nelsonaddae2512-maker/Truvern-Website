import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function isLockedStatus(status: any) {
  const s = String(status ?? "").toUpperCase();
  return ["COMPLETED", "SUBMITTED", "LOCKED"].includes(s);
}

export async function GET(_req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const assessmentId = Number(id);
    if (!Number.isFinite(assessmentId)) {
      return NextResponse.json({ error: "Invalid assessment id" }, { status: 400 });
    }

    const answers = await prisma.assessmentAnswer.findMany({
      where: { assessmentId },
      orderBy: { id: "asc" },
    });

    return NextResponse.json({ answers });
  } catch (e: any) {
    return NextResponse.json(
      { error: e?.message ?? "Failed to load answers" },
      { status: 500 }
    );
  }
}

export async function POST(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await ctx.params;
    const assessmentId = Number(id);
    if (!Number.isFinite(assessmentId)) {
      return NextResponse.json({ error: "Invalid assessment id" }, { status: 400 });
    }

    const run = await prisma.assessment.findUnique({
      where: { id: assessmentId },
      select: { status: true },
    });

    if (!run) {
      return NextResponse.json({ error: "Assessment run not found" }, { status: 404 });
    }

    if (isLockedStatus(run.status)) {
      return NextResponse.json(
        { error: `Run is locked (${String(run.status)}). Reopen to edit.` },
        { status: 409 }
      );
    }

    const body = await req.json().catch(() => null);
    const questionId = Number(body?.questionId);
    const value = body?.value;

    if (!Number.isFinite(questionId)) {
      return NextResponse.json({ error: "Invalid questionId" }, { status: 400 });
    }

    const existing = await prisma.assessmentAnswer.findFirst({
      where: { assessmentId, questionId },
      select: { id: true },
    });

    const answer = existing
      ? await prisma.assessmentAnswer.update({
          where: { id: existing.id },
          data: { value },
        })
      : await prisma.assessmentAnswer.create({
          data: { assessmentId, questionId, value },
        });

    return NextResponse.json({ answer });
  } catch (e: any) {
    return NextResponse.json(
      { error: e?.message ?? "Failed to save answer" },
      { status: 500 }
    );
  }
}
