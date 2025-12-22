import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

function toNumber(x: any): number | null {
  const n = typeof x === "number" ? x : typeof x === "string" ? Number(x) : NaN;
  return Number.isFinite(n) ? n : null;
}

function isNonEmptyString(v: any) {
  return typeof v === "string" && v.trim().length > 0;
}

function normalizeAnswerToDb(v: any): { value: string | null; valueJson: any | null } {
  // Clear
  if (v === null || v === undefined) return { value: null, valueJson: null };

  // Already string
  if (typeof v === "string") {
    const s = v.trim();
    return s.length ? { value: s, valueJson: null } : { value: null, valueJson: null };
  }

  // Boolean/number => store as string in `value`
  if (typeof v === "boolean") return { value: v ? "true" : "false", valueJson: null };
  if (typeof v === "number") return { value: String(v), valueJson: null };

  // Array/object => store in valueJson
  if (Array.isArray(v)) {
    return v.length ? { value: null, valueJson: v } : { value: null, valueJson: null };
  }
  if (typeof v === "object") {
    return Object.keys(v).length ? { value: null, valueJson: v } : { value: null, valueJson: null };
  }

  // Fallback
  return { value: String(v), valueJson: null };
}

type IncomingAnswer = {
  questionId?: any;
  assessmentQuestionId?: any;
  id?: any; // some clients send `id` meaning questionId
  value?: any;
};

/**
 * Fallback vendor resolution:
 * - If you have vendorUser join table, use it
 * - Else try vendor.portalUserId / clerkUserId / userId style fields
 */
async function resolveVendorIdForUser(userId: string): Promise<number | null> {
  const anyPrisma: any = prisma;

  // Optional join table if present
  if (typeof anyPrisma.vendorUser?.findFirst === "function") {
    const vu = await anyPrisma.vendorUser
      .findFirst({ where: { userId }, select: { vendorId: true } })
      .catch(() => null);
    const vid = toNumber(vu?.vendorId);
    if (vid) return vid;
  }

  // Common direct fields on Vendor
  const candidates = ["portalUserId", "clerkUserId", "userId"];
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

/**
 * ✅ IMPORTANT PATCH:
 * - If Clerk user exists but DB user row is missing, auto-create it.
 *   This prevents false "Unauthorized/Forbidden" during local dev.
 */
async function ensureDbUser(clerkId: string): Promise<number | null> {
  const existing = await prisma.user
    .findFirst({ where: { clerkId }, select: { id: true } })
    .catch(() => null);

  if (existing?.id) return existing.id;

  // create minimal user row (schema-safe: assumes User has clerkId)
  try {
    const created = await (prisma as any).user.create({
      data: { clerkId },
      select: { id: true },
    });
    return toNumber(created?.id);
  } catch {
    return null;
  }
}

async function resolveActor() {
  if (devBypassEnabled()) {
    return {
      mode: "DEV" as const,
      vendorId: toNumber(process.env.TRUVERN_DEV_VENDOR_ID ?? ""),
      clerkId: null as string | null,
      userRowId: null as number | null,
    };
  }

  const { userId } = auth();
  if (!userId) return null;

  // Try to read vendorId from Clerk metadata (nice-to-have, not required)
  const clerkUser = await currentUser().catch(() => null);
  const vendorIdRaw = (clerkUser?.publicMetadata as any)?.vendorId;
  const vendorIdFromMeta =
    typeof vendorIdRaw === "number"
      ? vendorIdRaw
      : typeof vendorIdRaw === "string"
      ? Number(vendorIdRaw)
      : NaN;

  // ✅ Auto-create DB user row if missing
  const userRowId = await ensureDbUser(userId);

  // Fallback vendor resolution if metadata missing
  const vendorId =
    Number.isFinite(vendorIdFromMeta)
      ? vendorIdFromMeta
      : await resolveVendorIdForUser(userId);

  return {
    mode: "CLERK" as const,
    vendorId: vendorId ? Number(vendorId) : null,
    clerkId: userId,
    userRowId: userRowId ?? null,
  };
}

async function hasOrgAccess(userRowId: number, organizationId: number) {
  const membership = await prisma.orgMembership.findFirst({
    where: { userId: userRowId, organizationId },
    select: { id: true },
  });
  return !!membership;
}

async function requireAccessToAssessment(assessmentId: number) {
  const actor = await resolveActor();
  if (!actor) return { ok: false as const, status: 401 as const, error: "Unauthorized" };

  const assessment = await prisma.assessment.findUnique({
    where: { id: assessmentId },
    select: { id: true, vendorId: true, organizationId: true, status: true, templateId: true },
  });

  if (!assessment) return { ok: false as const, status: 404 as const, error: "Not found" };

  // DEV bypass
  if (actor.mode === "DEV") return { ok: true as const, assessment, actor };

  // Vendor access
  if (actor.vendorId && Number(assessment.vendorId) === Number(actor.vendorId)) {
    return { ok: true as const, assessment, actor };
  }

  // Org access (requires DB user row)
  if (actor.userRowId && assessment.organizationId) {
    const ok = await hasOrgAccess(actor.userRowId, assessment.organizationId);
    if (ok) return { ok: true as const, assessment, actor };
  }

  return { ok: false as const, status: 403 as const, error: "Forbidden" };
}

async function computeProgress(assessmentId: number, templateId: number | null) {
  if (!templateId) return { total: 0, answered: 0 };

  const questionIds = await prisma.assessmentQuestion
    .findMany({
      where: { templateId },
      select: { id: true },
      take: 5000,
    })
    .then((rows) => rows.map((r) => r.id));

  const total = questionIds.length;
  if (!total) return { total: 0, answered: 0 };

  const answers = await prisma.assessmentAnswer.findMany({
    where: { assessmentId, questionId: { in: questionIds } },
    select: { value: true, valueJson: true },
  });

  const answered = answers.reduce((n, a) => {
    if (a.valueJson != null) return n + 1;
    if (isNonEmptyString(a.value)) return n + 1;
    return n;
  }, 0);

  return { total, answered };
}

export async function POST(req: Request) {
  try {
    const body = await req.json().catch(() => null);

    const assessmentId = toNumber(body?.assessmentId);
    if (!assessmentId) {
      return NextResponse.json({ ok: false, error: "Invalid payload" }, { status: 400 });
    }

    const access = await requireAccessToAssessment(assessmentId);
    if (!access.ok) {
      return NextResponse.json({ ok: false, error: access.error }, { status: access.status });
    }

    const assessment = access.assessment;
    const currentStatus = String(assessment.status ?? "").toUpperCase();

    // Hard lock
    if (currentStatus === "COMPLETED" || currentStatus === "ARCHIVED") {
      return NextResponse.json({ ok: false, error: "Assessment is locked" }, { status: 409 });
    }

    const batch: IncomingAnswer[] = Array.isArray(body?.answers)
      ? body.answers
      : [
          {
            questionId: body?.questionId,
            assessmentQuestionId: body?.assessmentQuestionId,
            id: body?.id,
            value: body?.value,
          },
        ];

    const normalized = batch
      .map((a) => {
        const qid = toNumber(a.questionId) ?? toNumber(a.assessmentQuestionId) ?? toNumber(a.id);
        return { questionId: qid, raw: a.value };
      })
      .filter((x) => x.questionId && x.questionId > 0) as Array<{ questionId: number; raw: any }>;

    if (normalized.length === 0) {
      return NextResponse.json({ ok: false, error: "Invalid payload" }, { status: 400 });
    }

    // Save answers (no manual updatedAt; schema uses @updatedAt)
    const saved = await prisma.$transaction(
      normalized.map(async (a) => {
        const { value, valueJson } = normalizeAnswerToDb(a.raw);

        return prisma.assessmentAnswer.upsert({
          where: { assessmentId_questionId: { assessmentId, questionId: a.questionId } },
          update: { value, valueJson },
          create: { assessmentId, questionId: a.questionId, value, valueJson },
        });
      })
    );

    // If run is still DRAFT, bump to IN_PROGRESS on first save
    await prisma.assessment.updateMany({
      where: { id: assessmentId, status: "DRAFT" },
      data: { status: "IN_PROGRESS", startedAt: new Date() },
    });

    // Explicit completion only (prevents premature COMPLETED)
    let updatedAssessment: any = null;
    const wantsComplete = body?.complete === true;

    if (wantsComplete) {
      const progress = await computeProgress(assessmentId, assessment.templateId ?? null);

      if (progress.total > 0 && progress.answered >= progress.total) {
        const now = new Date();
        updatedAssessment = await prisma.assessment.update({
          where: { id: assessmentId },
          data: {
            status: "COMPLETED",
            submittedAt: now,
            completedAt: now,
          },
          select: { id: true, status: true, submittedAt: true, completedAt: true, updatedAt: true },
        });
      } else {
        updatedAssessment = await prisma.assessment.findUnique({
          where: { id: assessmentId },
          select: { id: true, status: true, submittedAt: true, completedAt: true, updatedAt: true },
        });
      }
    } else {
      updatedAssessment = await prisma.assessment.findUnique({
        where: { id: assessmentId },
        select: { id: true, status: true, submittedAt: true, completedAt: true, updatedAt: true },
      });
    }

    const progress = await computeProgress(assessmentId, assessment.templateId ?? null);

    return NextResponse.json({
      ok: true,
      saved: saved.length,
      assessment: updatedAssessment,
      progress,
    });
  } catch (err) {
    console.error("SAVE ANSWERS ERROR", err);
    return NextResponse.json({ ok: false, error: "Server error" }, { status: 500 });
  }
}
