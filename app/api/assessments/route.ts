// app/api/assessments/route.ts
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

export async function POST(req: Request) {
  const org = await requireDbOrganization();

  let body: any = null;
  try {
    body = await req.json();
  } catch {
    return bad(400, "Invalid JSON body.");
  }

  const vendorId = Number(body?.vendorId);
  if (!Number.isFinite(vendorId)) return bad(400, "vendorId is required.");

  // ✅ Guardrail: org-scoped lookup + archived blocking
  const vendor = await prisma.vendor.findFirst({
    where: { id: vendorId, organizationId: org.id },
    select: { id: true, deletedAt: true },
  });

  if (!vendor) return bad(404, "Vendor not found.");
  if (vendor.deletedAt) return bad(409, "Vendor is archived. Restore to start an assessment.");

  const templateIdRaw = body?.templateId ?? null;
  const templateId = templateIdRaw == null ? null : Number(templateIdRaw);
  if (templateIdRaw != null && !Number.isFinite(templateId)) return bad(400, "Invalid templateId.");

  const title = body?.title ? String(body.title) : null;

  const dueAtRaw = body?.dueAt ?? null;
  const dueAt = parseDateOrNull(dueAtRaw);
  if (dueAtRaw && !dueAt) return bad(400, "Invalid dueAt date.");

  // ✅ Optional but production-safe: validate template belongs to org (or is global)
  if (templateId != null) {
    const tpl = await prisma.assessmentTemplate.findFirst({
      where: {
        id: templateId,
        OR: [{ organizationId: org.id }, { organizationId: null }],
      },
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
