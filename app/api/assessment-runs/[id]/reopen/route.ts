// app/api/assessment-runs/[id]/reopen/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";

type Ctx = { params: { id: string } } | { params: Promise<{ id: string }> };

async function getId(ctx: any) {
  const p = ctx?.params;
  if (!p) return null;
  if (typeof p.then === "function") {
    const resolved = await p;
    return resolved?.id ?? null;
  }
  return p?.id ?? null;
}

export async function POST(_req: NextRequest, ctx: Ctx) {
  try {
    const idStr = await getId(ctx);
    const assessmentId = Number(idStr);

    if (!Number.isFinite(assessmentId)) {
      return NextResponse.json({ ok: false, error: "Invalid id" }, { status: 400 });
    }

    const updated = await prisma.assessment.update({
      where: { id: assessmentId },
      data: {
        status: "IN_PROGRESS",
        completedAt: null,
      } as any,
    });

    return NextResponse.json({ ok: true, assessment: updated });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Unknown error" },
      { status: 500 }
    );
  }
}
