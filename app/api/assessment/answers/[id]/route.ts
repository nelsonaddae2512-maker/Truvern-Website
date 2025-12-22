import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

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

  const clerkUser = await currentUser().catch(() => null);
  const vendorIdRaw = (clerkUser?.publicMetadata as any)?.vendorId;
  const vendorId =
    typeof vendorIdRaw === "number"
      ? vendorIdRaw
      : typeof vendorIdRaw === "string"
      ? Number(vendorIdRaw)
      : NaN;

  const userRow = await prisma.user.findFirst({
    where: { clerkId: userId },
    select: { id: true },
  });

  return {
    mode: "CLERK" as const,
    vendorId: Number.isFinite(vendorId) ? vendorId : null,
    clerkId: userId,
    userRowId: userRow?.id ?? null,
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
    select: { id: true, vendorId: true, organizationId: true, status: true },
  });

  if (!assessment) return { ok: false as const, status: 404 as const, error: "Not found" };

  // DEV bypass
  if (actor.mode === "DEV") return { ok: true as const, assessment, actor };

  // Vendor access
  if (actor.vendorId && Number(assessment.vendorId) === Number(actor.vendorId)) {
    return { ok: true as const, assessment, actor };
  }

  // Org access
  if (actor.userRowId && assessment.organizationId) {
    const ok = await hasOrgAccess(actor.userRowId, assessment.organizationId);
    if (ok) return { ok: true as const, assessment, actor };
  }

  return { ok: false as const, status: 403 as const, error: "Forbidden" };
}

// PATCH /api/assessment/answers/:id
// Body: { value?, valueJson?, riskImpact? }
export async function PATCH(req: NextRequest) {
  try {
    const id = getAnswerIdFromUrl(req);
    if (id === null) {
      return NextResponse.json({ ok: false, error: "Invalid answer id" }, { status: 400 });
    }

    // Load answer to know which assessment we’re touching
    const existing = await prisma.assessmentAnswer.findUnique({
      where: { id },
      select: {
        id: true,
        assessmentId: true,
        questionId: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    if (!existing) {
      return NextResponse.json({ ok: false, error: "Not found" }, { status: 404 });
    }

    const access = await requireAccessToAssessment(existing.assessmentId);
    if (!access.ok) {
      return NextResponse.json({ ok: false, error: access.error }, { status: access.status });
    }

    const assessment = access.assessment;
    const status = String(assessment.status ?? "").toUpperCase();

    // Hard lock completed/archived
    if (status === "COMPLETED" || status === "ARCHIVED") {
      return NextResponse.json(
        { ok: false, error: "Assessment is locked" },
        { status: 409 }
      );
    }

    const body = await req.json().catch(() => ({} as any));

    const data: any = {};

    // Accept either:
    // - body.value (any type) -> normalize into value/valueJson
    // - OR body.valueJson explicitly (including null)
    if (body.value !== undefined) {
      const { value, valueJson } = normalizeAnswerToDb(body.value);
      data.value = value;
      data.valueJson = valueJson;
    } else if (body.valueJson !== undefined) {
      // if client explicitly only wants to set valueJson
      data.valueJson = body.valueJson;
      // if they pass null, we clear it; we do not force value unless they also provide body.value
    }

    if (body.riskImpact !== undefined) {
      if (body.riskImpact === null) data.riskImpact = null;
      else if (typeof body.riskImpact === "number") data.riskImpact = body.riskImpact;
    }

    // Require at least one editable field
    if (
      data.value === undefined &&
      data.valueJson === undefined &&
      data.riskImpact === undefined
    ) {
      return NextResponse.json(
        { ok: false, error: "Invalid payload" },
        { status: 400 }
      );
    }

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
      data: { status: "IN_PROGRESS", startedAt: new Date() },
    });

    return NextResponse.json({
      ok: true,
      ...updated,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    });
  } catch (error) {
    console.error("Error saving answer:", error);
    return NextResponse.json({ ok: false, error: "Failed to save answer" }, { status: 500 });
  }
}
