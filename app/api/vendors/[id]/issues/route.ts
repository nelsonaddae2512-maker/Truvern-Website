// app/api/vendors/[id]/issues/route.ts
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

function toNumber(x: any): number | null {
  const n = typeof x === "number" ? x : typeof x === "string" ? Number(x) : NaN;
  return Number.isFinite(n) ? n : null;
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

function parseStatusIn(req: NextRequest): string[] | null {
  const raw = req.nextUrl.searchParams.get("statusIn");
  if (!raw) return null;
  const parts = raw
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return parts.length ? parts : null;
}

export async function GET(req: NextRequest, ctx: { params: Promise<{ id: string }> }) {
  const { id } = await ctx.params;
  const vendorId = toNumber(id);

  if (!vendorId) {
    return NextResponse.json({ ok: false, error: "Invalid vendor id" }, { status: 400 });
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vendorId },
    select: { id: true, organizationId: true },
  });

  if (!vendor) {
    return NextResponse.json({ ok: false, error: "Vendor not found" }, { status: 404 });
  }

  const access = await requireOrgAccess(vendor.organizationId);
  if (!access.ok) {
    return NextResponse.json({ ok: false, error: access.error }, { status: access.status });
  }

  const statusIn = parseStatusIn(req);

  const issues = await prisma.issue.findMany({
    where: {
      vendorId: vendorId,
      ...(statusIn ? { status: { in: statusIn as any } } : {}),
    },
    orderBy: [
      { severity: "desc" as any },
      { updatedAt: "desc" as any },
      { createdAt: "desc" as any },
    ],
    take: 500,
    select: {
      id: true,
      title: true,
      severity: true,
      status: true,
      createdAt: true,
      vendor: { select: { id: true, name: true } },
      assessment: { select: { id: true, title: true } },
    },
  });

  return NextResponse.json({ ok: true, issues }, { status: 200 });
}
