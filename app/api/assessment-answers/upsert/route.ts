// app/api/assessment-answers/upsert/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";

function valueToString(v: any): string {
  if (v === null || v === undefined) return "";
  if (typeof v === "string") return v;
  if (typeof v === "number" || typeof v === "boolean") return String(v);
  try {
    return JSON.stringify(v);
  } catch {
    return String(v);
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const assessmentId = Number(body?.assessmentId);
    const questionId = Number(body?.questionId);
    const rawValue = body?.value;

    if (!Number.isFinite(assessmentId) || !Number.isFinite(questionId)) {
      return NextResponse.json(
        { ok: false, error: "Invalid assessmentId or questionId" },
        { status: 400 }
      );
    }

    const now = new Date();
    const value = valueToString(rawValue);

    const existing = await prisma.assessmentAnswer.findFirst({
      where: { assessmentId, questionId },
      select: { id: true },
    });

    const saved = existing
      ? await prisma.assessmentAnswer.update({
          where: { id: existing.id },
          data: {
            value,
            valueJson: rawValue ?? null,
            updatedAt: now,
          } as any,
        })
      : await prisma.assessmentAnswer.create({
          data: {
            assessmentId,
            questionId,
            value, // ✅ always a string
            valueJson: rawValue ?? null,
            updatedAt: now,
          } as any,
        });

    // Nudge assessment updatedAt so runs list stays fresh
    await prisma.assessment.update({
      where: { id: assessmentId },
      data: { updatedAt: now } as any,
    });

    return NextResponse.json({ ok: true, answer: saved });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Unknown error" },
      { status: 500 }
    );
  }
}
