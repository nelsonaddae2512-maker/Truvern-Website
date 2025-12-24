// app/api/usage/event/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const dynamic = "force-dynamic";

export async function POST(req: Request) {
  // requires authenticated org context (multi-tenant safe)
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

  const kind = typeof body?.kind === "string" ? body.kind.trim() : "";
  const vendorId =
    body?.vendorId == null ? null : Number.isFinite(Number(body.vendorId)) ? Number(body.vendorId) : null;
  const details = body?.details ?? null;

  if (!kind) {
    return NextResponse.json({ ok: false, error: "Missing kind" }, { status: 400 });
  }

  const created = await prisma.usageEvent.create({
    data: {
      organizationId: (org as any).id,
      vendorId: vendorId ?? undefined,
      kind,
      details: details ?? undefined,
    },
    select: { id: true, kind: true, createdAt: true },
  });

  return NextResponse.json({ ok: true, event: created });
}
