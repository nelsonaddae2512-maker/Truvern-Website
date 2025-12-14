// app/api/vendor-portal/assessment-answers/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

async function resolveVendorIdForUser(userId: string): Promise<number | null> {
  const anyPrisma: any = prisma;

  if (typeof anyPrisma.vendorUser?.findFirst === "function") {
    const vu = await anyPrisma.vendorUser.findFirst({
      where: { userId },
      select: { vendorId: true },
    }).catch(() => null);
    if (vu?.vendorId) return Number(vu.vendorId);
  }

  const candidates = ["portalUserId", "userId", "clerkUserId"];
  for (const field of candidates) {
    try {
      const v = await prisma.vendor.findFirst({
        where: { [field]: userId } as any,
        select: { id: true },
      });
      if (v?.id) return Number(v.id);
    } catch {
      // ignore
    }
  }

  return null;
}

export async function POST(req: Request) {
  try {
    const { userId } = auth();
    if (!userId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

    const body = await req.json().catch(() => null);
    const assessmentId = Number(body?.assessmentId);
    const vendorId = Number(body?.vendorId);
    const questionId = Number(body?.questionId);
    const value = body?.value;

    if (!Number.isFinite(assessmentId) || !Number.isFinite(questionId) || !Number.isFinite(vendorId)) {
      return NextResponse.json({ error: "Invalid payload" }, { status: 400 });
    }

    // Ensure caller is the vendor
    const resolvedVendorId = await resolveVendorIdForUser(userId);
    if (!resolvedVendorId || resolvedVendorId !== vendorId) {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 });
    }

    // Ensure run belongs to vendor
    const RunModel: any = (prisma as any).assessmentRun ?? (prisma as any).assessment;
    const run = RunModel
      ? await RunModel.findUnique({
          where: { id: assessmentId },
          select: { id: true, vendorId: true },
        }).catch(() => null)
      : null;

    const runVendorId = Number(run?.vendorId);
    if (!run || !Number.isFinite(runVendorId) || runVendorId !== vendorId) {
      return NextResponse.json({ error: "Forbidden" }, { status: 403 });
    }

    // Upsert answer: (assessmentId, questionId) unique-ish, but schemas vary.
    // We do "findFirst then update/create" to stay schema-safe.
    const anyPrisma: any = prisma;
    if (typeof anyPrisma.assessmentAnswer?.findFirst !== "function") {
      return NextResponse.json({ error: "Assessment answers not available" }, { status: 400 });
    }

    const existing = await anyPrisma.assessmentAnswer.findFirst({
      where: { assessmentId, questionId },
      select: { id: true },
    }).catch(() => null);

    let saved: any = null;

    if (existing?.id && typeof anyPrisma.assessmentAnswer.update === "function") {
      saved = await anyPrisma.assessmentAnswer.update({
        where: { id: existing.id },
        data: { value, updatedAt: new Date() },
        select: { id: true, assessmentId: true, questionId: true, value: true, updatedAt: true },
      });
    } else if (typeof anyPrisma.assessmentAnswer.create === "function") {
      saved = await anyPrisma.assessmentAnswer.create({
        data: { assessmentId, questionId, value, updatedAt: new Date() },
        select: { id: true, assessmentId: true, questionId: true, value: true, updatedAt: true },
      });
    }

    return NextResponse.json({ ok: true, answer: saved });
  } catch (e: any) {
    return NextResponse.json({ error: e?.message || "Server error" }, { status: 500 });
  }
}
