import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function isDevBypass(req: Request) {
  const devKey = req.headers.get("x-dev-seed-key");
  return process.env.NODE_ENV !== "production" && devKey === "local-dev";
}

function toSlug(input: string) {
  return input
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

async function getOrgIdForRequest(req: Request): Promise<number> {
  // DEV BYPASS: allow PowerShell calls without Clerk cookies
  if (isDevBypass(req)) {
    const hdr = req.headers.get("x-org-id");
    const fromHdr = hdr ? Number(String(hdr).trim()) : NaN;
    if (Number.isFinite(fromHdr) && fromHdr > 0) return fromHdr;

    // fallback: most recent org in DB
    const org = await prisma.organization.findFirst({
      orderBy: { id: "desc" } as any,
      select: { id: true } as any,
    } as any);

    if (!org?.id) throw new Error("No organizations found in DB for dev bypass.");
    return org.id;
  }

  // NORMAL: enforce Clerk + org context
  const { userId } = await auth();
  if (!userId) throw new Error("unauthorized");
  const org = await requireDbOrganization();
  return org.id;
}

async function ensureUniqueVendorSlug(organizationId: number, name: string) {
  const base = toSlug(name) || "vendor";
  let slug = base;
  let i = 1;

  while (
    await prisma.vendor.findFirst({
      where: { organizationId, slug } as any,
      select: { id: true } as any,
    } as any)
  ) {
    i += 1;
    slug = `${base}-${i}`;
  }

  return slug;
}

export async function GET(req: Request) {
  try {
    const organizationId = await getOrgIdForRequest(req);

    const vendors = await prisma.vendor.findMany({
      where: { organizationId } as any,
      orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
      take: 500,
      select: {
        id: true,
        name: true,
        slug: true as any,
        summary: true as any,
        category: true as any,
        tier: true as any,
        criticality: true as any,
        updatedAt: true,
        createdAt: true,
        organizationId: true,
      } as any,
    } as any);

    return NextResponse.json({
  ok: true,
  id: vendor.id,
  vendorId: vendor.id,
  vendor,
});

  } catch (e: any) {
    const msg = e?.message || String(e);
    const status = msg === "unauthorized" ? 401 : 500;
    return NextResponse.json({ ok: false, error: msg }, { status });
  }
}

export async function POST(req: Request) {
  try {
    const organizationId = await getOrgIdForRequest(req);
    const body = await req.json().catch(() => ({}));

    const name = String(body?.name || "").trim();
    if (!name) {
      return NextResponse.json(
        { ok: false, error: "Vendor name is required" },
        { status: 400 }
      );
    }

    const slug = await ensureUniqueVendorSlug(organizationId, name);

    const vendor = await prisma.vendor.create({
      data: {
        organizationId,
        name,
        slug,
        summary: body?.summary ?? null,
        category: body?.category ?? null,
        tier: body?.tier ?? null,
        criticality: body?.criticality ?? null,
      } as any,
    } as any);

    return NextResponse.json({ ok: true, vendor });
  } catch (e: any) {
    const msg = e?.message || String(e);
    const status = msg === "unauthorized" ? 401 : 500;
    return NextResponse.json({ ok: false, error: msg }, { status });
  }
}