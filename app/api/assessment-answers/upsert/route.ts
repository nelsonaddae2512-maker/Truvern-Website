// app/api/assessment-answers/upsert/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import { requireDbOrganization } from "@/lib/org-db";

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

/**
 * Ensure the run/assessment belongs to the currently selected DB org.
 *
 * IMPORTANT:
 * - Some environments store org on Assessment/AssessmentRun as `organizationId`
 * - Some older paths only allow resolving org through Vendor.organizationId
 * We support both safely.
 */
async function assertRunInOrg(assessmentId: number) {
  const org = await requireDbOrganization();

  const RunModel: any =
    (prisma as any).assessmentRun ?? (prisma as any).assessment;

  if (!RunModel?.findUnique) {
    return {
      ok: false as const,
      status: 400,
      error: "Assessments not available",
    };
  }

  const run = await RunModel.findUnique({
    where: { id: assessmentId },
    select: {
      id: true,

      // Prefer direct orgId on the run/assessment (common)
      organizationId: true as any,

      vendorId: true,
      vendor: { select: { id: true, organizationId: true } },
    },
  }).catch(() => null);

  if (!run?.id) {
    return { ok: false as const, status: 404, error: "Run not found" };
  }

  const orgId = Number(org?.id);

  // Determine run org id
  const directOrgId = Number((run as any)?.organizationId);
  const vendorOrgId = Number((run as any)?.vendor?.organizationId);

  const runOrgId = Number.isFinite(directOrgId)
    ? directOrgId
    : Number.isFinite(vendorOrgId)
    ? vendorOrgId
    : NaN;

  if (!Number.isFinite(orgId) || !Number.isFinite(runOrgId)) {
    return {
      ok: false as const,
      status: 403,
      error: "Forbidden",
    };
  }

  if (runOrgId !== orgId) {
    return {
      ok: false as const,
      status: 403,
      error: "Forbidden",
    };
  }

  return { ok: true as const, orgId };
}

export async function POST(req: NextRequest) {
  try {
    const { userId } = auth();
    if (!userId) {
      return NextResponse.json(
        { ok: false, error: "Unauthorized" },
        { status: 401 }
      );
    }

    const body = await req.json().catch(() => null);

    const assessmentId = Number(body?.assessmentId);
    const questionId = Number(body?.questionId);

    // Prefer valueJson if client sends it, otherwise use value
    const rawValue =
      body?.valueJson !== undefined ? body?.valueJson : body?.value;

    if (!Number.isFinite(assessmentId) || !Number.isFinite(questionId)) {
      return NextResponse.json(
        { ok: false, error: "Invalid assessmentId or questionId" },
        { status: 400 }
      );
    }

    const authz = await assertRunInOrg(assessmentId);
    if (!authz.ok) {
      return NextResponse.json(
        { ok: false, error: authz.error },
        { status: authz.status }
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
            value, // always a string
            valueJson: rawValue ?? null,
            updatedAt: now,
          } as any,
        });

    // Nudge assessment updatedAt so runs list stays fresh
    const RunModel: any =
      (prisma as any).assessmentRun ?? (prisma as any).assessment;

    if (RunModel?.update) {
      await RunModel.update({
        where: { id: assessmentId },
        data: { updatedAt: now } as any,
      }).catch(() => null);
    }

    return NextResponse.json({ ok: true, answer: saved });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Unknown error" },
      { status: 500 }
    );
  }
}
