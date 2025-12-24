import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";

function parseId(raw: unknown): number | null {
  const v = Array.isArray(raw) ? raw[0] : raw;
  const s = typeof v === "string" ? v.trim() : v == null ? "" : String(v);
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

export async function POST(
  _req: Request,
  ctx: { params: Promise<{ id: string }> }
) {
  const { userId } = await auth();
  if (!userId) {
    return NextResponse.json({ ok: false, error: "unauthorized" }, { status: 401 });
  }

  const { id } = await ctx.params;
  const runId = parseId(id);
  if (!runId) {
    return NextResponse.json({ ok: false, error: "invalid id" }, { status: 400 });
  }

  try {
    const updated = await prisma.assessmentRun.update({
      where: { id: runId } as any,
      data: { status: "CANCELLED" } as any, // change if your enum uses CANCELED/ABORTED/etc.
    });

    return NextResponse.json({ ok: true, run: updated });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: "cancel failed", detail: e?.message || String(e) },
      { status: 500 }
    );
  }
}