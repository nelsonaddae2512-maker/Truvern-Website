// app/api/vendors/[id]/assessments/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function json(status: number, data: any) {
  return NextResponse.json(data, { status });
}

function bad(status: number, error: string) {
  return json(status, { ok: false, error });
}

function parseDateOrNull(v: any): Date | null {
  if (v == null || v === "") return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? null : d;
}

type ParamsPromise = Promise<{ id: string }>;

export async function POST(req: Request, ctx: { params: ParamsPromise }) {
  const org = await requireDbOrganization();
  const { id } = await ctx.params;

  const idNum = Number(id);
  if (!Number.isFinite(idNum)) return bad(400, "Invalid vendor id.");

  // ✅ Org-scoped vendor lookup + archived block
  const vendor = await prisma.vendor.findFirst({
    where: { id: idNum, organizationId: org.id },
    select: { id: true, deletedAt: true },
  });

  if (!vendor) return bad(404, "Vendor not found.");
  if (vendor.deletedAt) return bad(409, "Vendor is archived. Restore to start an assessment.");

  let body: any = null;
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const templateIdRaw = body?.templateId ?? null;
  const templateId = templateIdRaw == null ? null : Number(templateIdRaw);
  if (templateIdRaw != null && !Number.isFinite(templateId)) {
    return bad(400, "Invalid templateId.");
  }

  const title = body?.title ? String(body.title) : null;

  const dueAtRaw = body?.dueAt ?? null;
  const dueAt = parseDateOrNull(dueAtRaw);
  if (dueAtRaw && !dueAt) return bad(400, "Invalid dueAt date.");

  // Optional: validate template belongs to org (if provided)
  if (templateId != null) {
    const tpl = await prisma.assessmentTemplate.findFirst({
      where: { id: templateId, OR: [{ organizationId: org.id }, { organizationId: null }] },
      select: { id: true },
    });
    if (!tpl) return bad(400, "Template not found for this organization.");
  }

  const created = await prisma.assessment.create({
    data: {
      organizationId: org.id,
      vendorId: vendor.id,
      templateId,
      title,
      dueAt,
      status: "DRAFT" as any,
    },
    select: { id: true, vendorId: true, status: true, createdAt: true },
  });

  return json(201, { ok: true, assessment: created });
}
