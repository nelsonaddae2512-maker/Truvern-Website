// app/api/vendors/[id]/issues/export.csv/route.ts
import { NextRequest, NextResponse } from "next/server";
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

async function requireOrgAccess(organizationId: number) {
  if (devBypassEnabled()) return { ok: true as const };

  const { userId } = auth();
  if (!userId) return { ok: false as const, status: 401 as const, error: "Unauthorized" };

  const user = await prisma.user.findFirst({
    where: { clerkId: userId },
    select: { id: true },
  });

  if (!user) return { ok: false as const, status: 401 as const, error: "Unauthorized" };

  const membership = await prisma.orgMembership.findFirst({
    where: { userId: user.id, organizationId },
    select: { id: true },
  });

  if (!membership) return { ok: false as const, status: 403 as const, error: "Forbidden" };
  return { ok: true as const };
}

function csvEscape(value: any) {
  if (value == null) return "";
  const s = String(value);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}
function toCsv(rows: any[][]) {
  return rows.map((r) => r.map(csvEscape).join(",")).join("\n");
}

export async function GET(_req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  const vendorId = Number(id);

  if (!Number.isFinite(vendorId)) {
    return NextResponse.json({ ok: false, error: "Invalid vendor id" }, { status: 400 });
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    select: { id: true, name: true, organizationId: true },
  });

  if (!vendor) {
    return NextResponse.json({ ok: false, error: "Vendor not found" }, { status: 404 });
  }

  const access = await requireOrgAccess(vendor.organizationId);
  if (!access.ok) {
    return NextResponse.json({ ok: false, error: access.error }, { status: access.status });
  }

  const issues = await prisma.issue.findMany({
    where: { vendorId },
    orderBy: [{ createdAt: "desc" as any }],
    take: 5000,
    select: {
      id: true,
      title: true,
      severity: true,
      status: true,
      dueAt: true,
      createdAt: true,
      updatedAt: true,
      assessment: { select: { id: true, title: true } },
    },
  });

  const rows: any[][] = [];
  rows.push([
    "Vendor",
    "IssueId",
    "Title",
    "Severity",
    "Status",
    "AssessmentId",
    "AssessmentTitle",
    "DueAt",
    "CreatedAt",
    "UpdatedAt",
  ]);

  for (const i of issues) {
    rows.push([
      vendor.name,
      i.id,
      i.title ?? "",
      String(i.severity ?? ""),
      String(i.status ?? ""),
      i.assessment?.id ?? "",
      i.assessment?.title ?? "",
      i.dueAt ? new Date(i.dueAt as any).toISOString() : "",
      i.createdAt ? new Date(i.createdAt as any).toISOString() : "",
      i.updatedAt ? new Date(i.updatedAt as any).toISOString() : "",
    ]);
  }

  const csv = toCsv(rows);
  const filename = `truvern_vendor_${vendorId}_findings.csv`;

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Cache-Control": "no-store",
    },
  });
}
