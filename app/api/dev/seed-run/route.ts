// app/api/dev/seed-run/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const REQUIRED_KEY = "local-dev";

// ✅ your Clerk org id (string)
const DEFAULT_CLERK_ORG_ID = "org_375gF9XhJpNAZCcSTl7kvexpibg";

function json(status: number, data: any) {
  return new NextResponse(JSON.stringify(data, null, 2), {
    status,
    headers: { "content-type": "application/json" },
  });
}

export async function POST(req: Request) {
  try {
    // header keys are lowercase in Next
    const key = req.headers.get("x-dev-seed-key") || "";

    if (key !== REQUIRED_KEY) {
      return json(401, {
        ok: false,
        error: "Unauthorized",
        hint: "Missing/invalid x-dev-seed-key header",
      });
    }

    // Optional JSON body override: { clerkOrgId?: string, vendorId?: number, assessmentId?: number }
    let body: any = {};
    try {
      body = await req.json();
    } catch {
      body = {};
    }

    const clerkOrgId = (body?.clerkOrgId || DEFAULT_CLERK_ORG_ID) as string;

    const org = await prisma.organization.findFirst({
      where: { clerkOrgId },
      select: { id: true, name: true, clerkOrgId: true },
    });

    if (!org) {
      return json(404, {
        ok: false,
        error: "Organization not found in DB for clerkOrgId",
        clerkOrgId,
        hint: "Check Organization.clerkOrgId in your database matches this value.",
      });
    }

    const vendorId =
      typeof body?.vendorId === "number" && Number.isFinite(body.vendorId)
        ? body.vendorId
        : null;

    const assessmentId =
      typeof body?.assessmentId === "number" && Number.isFinite(body.assessmentId)
        ? body.assessmentId
        : null;

    const run = await prisma.assessmentRun.create({
      data: {
        organizationId: org.id,
        vendorId: vendorId ?? undefined,
        assessmentId: assessmentId ?? undefined,
        status: "IN_PROGRESS",
        startedAt: new Date(),
      },
      select: {
        id: true,
        status: true,
        organizationId: true,
        vendorId: true,
        assessmentId: true,
        createdAt: true,
      },
    });

    return json(200, {
      ok: true,
      org,
      run,
      open: `/assessment/runs/${run.id}`,
    });
  } catch (e: any) {
    return json(500, { ok: false, error: "Internal error", message: String(e?.message || e) });
  }
}
