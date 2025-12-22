// app/api/vendors/list/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import { getCurrentOrgId } from "@/lib/current-org";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

function toInt(v: string | null): number | null {
  if (!v) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

async function requireOrgContext(): Promise<
  | { ok: true; organizationId: number }
  | { ok: false; status: number; error: string }
> {
  if (devBypassEnabled()) {
    const envOrg = toInt(process.env.TRUVERN_DEV_ORG_ID ?? null);
    if (envOrg) return { ok: true, organizationId: envOrg };
  }

  const orgId = await getCurrentOrgId().catch(() => null);
  if (orgId) return { ok: true, organizationId: orgId };

  const { userId } = auth();
  if (!userId) return { ok: false, status: 401, error: "Unauthorized" };

  return { ok: false, status: 403, error: "No organization context" };
}

export async function GET(_req: NextRequest) {
  const access = await requireOrgContext();
  if (!access.ok) {
    return NextResponse.json({ ok: false, error: access.error }, { status: access.status });
  }

  const vendors = await prisma.vendor.findMany({
    where: { organizationId: access.organizationId, deletedAt: null },
    select: { id: true, name: true },
    orderBy: [{ name: "asc" }],
    take: 500,
  });

  return NextResponse.json({ ok: true, vendors }, { status: 200 });
}
