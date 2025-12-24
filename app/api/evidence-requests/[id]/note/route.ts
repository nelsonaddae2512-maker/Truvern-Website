// app/api/evidence-requests/[id]/note/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const dynamic = "force-dynamic";

function parseIdFromUrl(url: string): number | null {
  try {
    const u = new URL(url);
    const parts = u.pathname.split("/").filter(Boolean);
    const id = Number(parts[parts.length - 2] === "note" ? parts[parts.length - 3] : parts[parts.length - 2]);
    return Number.isFinite(id) ? id : null;
  } catch {
    return null;
  }
}

export async function POST(req: Request) {
  const requestId = parseIdFromUrl(req.url);
  if (!requestId) {
    return NextResponse.json({ ok: false, error: "Invalid request id" }, { status: 400 });
  }

  // Enforce org context (Clerk session / membership-based)
  const org = await requireDbOrganization();
  if ((org as any)?._needsOrgSelection) {
    return NextResponse.json(
      { ok: false, error: "Organization selection required" },
      { status: 409 }
    );
  }

  let body: any = {};
  try {
    body = await req.json();
  } catch {
    body = {};
  }

  const reviewNote = typeof body?.reviewNote === "string" ? body.reviewNote : "";

  // Ensure the request belongs to this org (multi-tenant safety)
  const existing = await prisma.evidenceRequest.findFirst({
    where: { id: requestId, organizationId: (org as any).id },
    select: { id: true },
  });

  if (!existing) {
    return NextResponse.json({ ok: false, error: "Not found" }, { status: 404 });
  }

  const updated = await prisma.evidenceRequest.update({
    where: { id: requestId },
    data: { reviewNote },
    select: { id: true, status: true, reviewNote: true, updatedAt: true },
  });

  return NextResponse.json({ ok: true, request: updated });
}
