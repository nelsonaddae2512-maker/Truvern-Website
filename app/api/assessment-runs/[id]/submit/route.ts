import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

/**
 * Robust org access:
 * - If TRUVERN_DEV_BYPASS_AUTH=1 (dev), allow.
 * - Require Clerk userId.
 * - Ensure a DB user exists for clerkId (auto-create minimal row if missing).
 * - Require org membership.
 */
async function requireOrgAccess(organizationId: number) {
  if (devBypassEnabled()) return { ok: true as const };

  const { userId } = auth();
  if (!userId) {
    return { ok: false as const, status: 401 as const, error: "Unauthorized" };
  }

  // Try to find DB user; if missing, auto-create a minimal row so dev isn't blocked
  let user = await prisma.user.findFirst({
    where: { clerkId: userId },
    select: { id: true },
  });

  if (!user) {
    try {
      // schema-safe minimal create (assumes clerkId exists on User model)
      user = await (prisma as any).user.create({
        data: { clerkId: userId },
        select: { id: true },
      });
    } catch {
      // If schema doesn't allow create like this, fall back to Unauthorized
      return { ok: false as const, status: 401 as const, error: "Unauthorized" };
    }
  }

  const membership = await prisma.orgMembership.findFirst({
    where: { userId: user.id, organizationId },
    select: { id: true },
  });

  if (!membership) {
    return { ok: false as const, status: 403 as const, error: "Forbidden" };
  }

  return { ok: true as const, userDbId: user.id };
}

async function answeredCountForAssessment(assessmentId: number) {
  return prisma.assessmentAnswer.count({
    where: {
      assessmentId,
      OR: [
        { valueJson: { not: null } },
        { value: { not: null, notIn: ["", " "] } },
      ],
    },
  });
}

async function totalQuestionsForAssessment(assessment: { templateId: number | null }) {
  if (!assessment.templateId) return 0;
  return prisma.assessmentQuestion.count({
    where: { templateId: assessment.templateId },
  });
}

function computeBaselineScore(answered: number, total: number) {
  if (!total || total <= 0) return 0;
  const pct = (answered / total) * 100;
  const rounded = Math.round(pct);
  return Math.max(0, Math.min(100, rounded));
}

export async function POST(_req: Request, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  const assessmentId = Number(id);

  if (!Number.isFinite(assessmentId)) {
    return NextResponse.json({ ok: false, error: "Invalid id" }, { status: 400 });
  }

  const assessment = await prisma.assessment.findUnique({
    where: { id: assessmentId },
    select: {
      id: true,
      organizationId: true,
      vendorId: true,
      status: true,
      templateId: true,
      score: true,
      confidentialityScore: true,
      integrityScore: true,
      availabilityScore: true,
    },
  });

  if (!assessment) {
    return NextResponse.json({ ok: false, error: "Not found" }, { status: 404 });
  }

  const access = await requireOrgAccess(assessment.organizationId);
  if (!access.ok) {
    return NextResponse.json({ ok: false, error: access.error }, { status: access.status });
  }

  // If already completed, ensure baseline score + snapshot exist (best-effort)
  if (assessment.status === "COMPLETED") {
    try {
      const [answeredCount, totalCount] = await Promise.all([
        answeredCountForAssessment(assessmentId),
        totalQuestionsForAssessment(assessment),
      ]);

      const baseline = computeBaselineScore(answeredCount, totalCount);

      await prisma.$transaction(async (tx) => {
        if (assessment.score == null) {
          await tx.assessment.update({
            where: { id: assessmentId },
            data: {
              score: baseline,
              confidentialityScore: baseline,
              integrityScore: baseline,
              availabilityScore: baseline,
            },
          });
        }

        await tx.vendorRiskSnapshot.create({
          data: { vendorId: assessment.vendorId, score: baseline },
        });

        await tx.vendor.update({
          where: { id: assessment.vendorId },
          data: { riskScore: baseline },
        });
      });
    } catch (e) {
      console.error("[submit] completed backfill/snapshot failed", e);
    }

    return NextResponse.json({ ok: true, assessment }, { status: 200 });
  }

  if (assessment.status === "ARCHIVED") {
    return NextResponse.json({ ok: false, error: "Assessment is archived" }, { status: 409 });
  }

  const [answeredCount, totalCount] = await Promise.all([
    answeredCountForAssessment(assessmentId),
    totalQuestionsForAssessment(assessment),
  ]);

  if (totalCount > 0 && answeredCount < totalCount) {
    return NextResponse.json(
      {
        ok: false,
        error: `Cannot submit: answered ${answeredCount}/${totalCount}`,
        answeredCount,
        totalCount,
      },
      { status: 400 }
    );
  }

  const now = new Date();
  const baselineScore = computeBaselineScore(answeredCount, totalCount);

  const updated = await prisma.$transaction(async (tx) => {
    const a = await tx.assessment.update({
      where: { id: assessmentId },
      data: {
        status: "COMPLETED",
        submittedAt: now,
        completedAt: now,
        score: baselineScore,
        confidentialityScore: baselineScore,
        integrityScore: baselineScore,
        availabilityScore: baselineScore,
      },
      select: {
        id: true,
        status: true,
        submittedAt: true,
        completedAt: true,
        updatedAt: true,
        score: true,
        confidentialityScore: true,
        integrityScore: true,
        availabilityScore: true,
      },
    });

    await tx.vendorRiskSnapshot.create({
      data: { vendorId: assessment.vendorId, score: baselineScore },
    });

    await tx.vendor.update({
      where: { id: assessment.vendorId },
      data: { riskScore: baselineScore },
    });

    return a;
  });

  return NextResponse.json(
    {
      ok: true,
      assessment: updated,
      progress: { answered: answeredCount, total: totalCount },
    },
    { status: 200 }
  );
}
