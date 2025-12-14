import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";

export const runtime = "nodejs";

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

export async function POST(req: Request) {
  try {
    // Basic auth gate (enterprise-ready). In dev bypass, allow without login.
    const { userId } = auth();
    if (!userId && !devBypassEnabled()) {
      return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json();
    const vendorId = Number(body.vendorId);

    if (!Number.isFinite(vendorId)) {
      return NextResponse.json({ ok: false, error: "Invalid vendorId" }, { status: 400 });
    }

    const created = await prisma.evidenceRequest.create({
      data: {
        vendorId,
        organizationId: body.organizationId ? Number(body.organizationId) : null,
        requestedBy: userId ?? "dev-bypass",
        kind: body.kind ?? "OTHER",
        label: String(body.label ?? "").trim() || "Evidence request",
        description: body.description ? String(body.description) : null,
        dueAt: body.dueAt ? new Date(body.dueAt) : null,
        status: "OPEN",
      } as any,
    });

    return NextResponse.json({ ok: true, request: created });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Failed to create evidence request" },
      { status: 500 }
    );
  }
}
