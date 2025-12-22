// app/api/activity-feed/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";
import { decodeCursor, fetchActivityEvents } from "@/lib/activity-feed";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function json(data: any, init?: ResponseInit) {
  return new NextResponse(JSON.stringify(data, null, 2), {
    ...init,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      ...(init?.headers ?? {}),
    },
  });
}

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

async function resolveOrgId(): Promise<number | null> {
  if (devBypassEnabled()) {
    const raw = process.env.TRUVERN_DEV_ORG_ID ?? "";
    const n = Number(raw);
    return Number.isFinite(n) ? n : null;
  }

  const { userId } = auth();
  if (!userId) return null;

  // Pull Clerk profile (email is the best bridge to your DB user table)
  let clerkEmail: string | null = null;
  let clerkName: string | null = null;
  let metaOrgId: number | null = null;
  let metaOrgSlug: string | null = null;

  try {
    const cu = await currentUser();
    clerkEmail = cu?.emailAddresses?.[0]?.emailAddress ?? null;
    clerkName = cu?.fullName ?? null;

    const pm = (cu?.publicMetadata as any) || {};
    const rawOrgId = pm.organizationId ?? pm.orgId ?? null;
    const rawOrgSlug = pm.organizationSlug ?? pm.orgSlug ?? null;

    const n =
      typeof rawOrgId === "number" ? rawOrgId : Number(rawOrgId ?? "");
    metaOrgId = Number.isFinite(n) ? n : null;
    metaOrgSlug =
      typeof rawOrgSlug === "string" && rawOrgSlug ? rawOrgSlug : null;
  } catch {
    // ignore; we can still try DB lookups by clerkId
  }

  // If Clerk metadata includes orgId, trust but verify it exists.
  if (metaOrgId) {
    const org = await prisma.organization.findUnique({
      where: { id: metaOrgId },
      select: { id: true },
    });
    if (org) return org.id;
  }

  // 1) Try DB user by clerkId
  let dbUser =
    (await prisma.user.findFirst({
      where: { clerkId: userId },
      select: { id: true, organizationId: true, email: true },
    })) ?? null;

  // 2) If not found, try by email (and attach clerkId)
  if (!dbUser && clerkEmail) {
    const byEmail = await prisma.user.findFirst({
      where: { email: clerkEmail },
      select: { id: true, organizationId: true, email: true },
    });

    if (byEmail) {
      await prisma.user.update({
        where: { id: byEmail.id },
        data: { clerkId: userId, name: clerkName ?? undefined },
      });
      dbUser = byEmail;
    }
  }

  // 3) If still not found, create a DB user row (minimal, safe)
  if (!dbUser && clerkEmail) {
    dbUser = await prisma.user.create({
      data: {
        email: clerkEmail,
        name: clerkName ?? undefined,
        clerkId: userId,
      },
      select: { id: true, organizationId: true, email: true },
    });
  }

  // 4) If Clerk metadata includes orgSlug, resolve it and optionally set user's orgId
  if (dbUser && !dbUser.organizationId && metaOrgSlug) {
    const org = await prisma.organization.findFirst({
      where: { slug: metaOrgSlug },
      select: { id: true },
    });
    if (org) {
      await prisma.user.update({
        where: { id: dbUser.id },
        data: { organizationId: org.id },
      });
      return org.id;
    }
  }

  // 5) Use user's primary organization if set
  if (dbUser?.organizationId) return dbUser.organizationId;

  // 6) Fall back to first membership
  if (dbUser?.id) {
    const mem = await prisma.orgMembership.findFirst({
      where: { userId: dbUser.id },
      select: { organizationId: true },
      orderBy: { createdAt: "asc" as any },
    });
    if (mem?.organizationId) return mem.organizationId;
  }

  // ✅ DEV SELF-HEAL:
  // If user is signed in but has no org linkage yet, attach them to the first org.
  // This only runs in dev to unblock local development and testing.
  if (process.env.NODE_ENV !== "production" && dbUser?.id) {
    const firstOrg = await prisma.organization.findFirst({
      orderBy: { createdAt: "asc" as any },
      select: { id: true },
    });

    if (firstOrg) {
      await prisma.orgMembership.upsert({
        where: {
          userId_organizationId: {
            userId: dbUser.id,
            organizationId: firstOrg.id,
          },
        },
        update: {},
        create: {
          userId: dbUser.id,
          organizationId: firstOrg.id,
          role: "OWNER" as any,
        },
      });

      await prisma.user.update({
        where: { id: dbUser.id },
        data: { organizationId: firstOrg.id },
      });

      return firstOrg.id;
    }
  }

  return null;
}

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);
    const scope = (url.searchParams.get("scope") || "org").toLowerCase();
    const takeRaw = url.searchParams.get("take");
    const take = Math.max(1, Math.min(100, Number(takeRaw ?? "25") || 25));

    const cursorRaw = url.searchParams.get("cursor");
    const cursor = decodeCursor(cursorRaw);

    const orgId = await resolveOrgId();
    if (!orgId) return json({ error: "Unauthorized" }, { status: 401 });

    let vendorId: number | null = null;

    if (scope === "vendor") {
      const vendorIdRaw = url.searchParams.get("vendorId");
      const n = Number(vendorIdRaw ?? "");
      if (!Number.isFinite(n)) {
        return json({ error: "Missing or invalid vendorId" }, { status: 400 });
      }
      vendorId = n;

      // Ensure vendor belongs to org
      const v = await prisma.vendor.findFirst({
        where: { id: vendorId, organizationId: orgId },
        select: { id: true },
      });
      if (!v) return json({ error: "Vendor not found" }, { status: 404 });
    }

    const result = await fetchActivityEvents({
      organizationId: orgId,
      vendorId,
      take,
      cursor,
    });

    return json({
      scope: vendorId ? "vendor" : "org",
      organizationId: orgId,
      vendorId,
      take,
      cursor: cursorRaw ?? null,
      nextCursor: result.nextCursor,
      items: result.items,
    });
  } catch (e: any) {
    console.error("GET /api/activity-feed failed:", e);
    return json({ error: "Internal error" }, { status: 500 });
  }
}
