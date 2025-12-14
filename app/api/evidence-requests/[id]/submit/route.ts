// app/api/evidence-requests/[id]/submit/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";

export const runtime = "nodejs";

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

async function resolveVendorId() {
  if (devBypassEnabled()) {
    const v = Number(process.env.TRUVERN_DEV_VENDOR_ID ?? "");
    return Number.isFinite(v) ? v : null;
  }

  const { userId } = auth();
  if (!userId) return null;

  const user = await currentUser();
  const vendorIdRaw = (user?.publicMetadata as any)?.vendorId;

  const vendorId =
    typeof vendorIdRaw === "number"
      ? vendorIdRaw
      : typeof vendorIdRaw === "string"
      ? Number(vendorIdRaw)
      : NaN;

  return Number.isFinite(vendorId) ? vendorId : null;
}

export async function POST(req: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const requestId = Number(id);
    if (!Number.isFinite(requestId)) {
      return NextResponse.json({ ok: false, error: "Invalid request id" }, { status: 400 });
    }

    const vendorId = await resolveVendorId();
    if (!vendorId) {
      return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json().catch(() => ({}));
    const notes = body?.notes ? String(body.notes) : null;

    const existing = await prisma.evidenceRequest.findUnique({
      where: { id: requestId },
      select: { id: true, vendorId: true, status: true },
    });

    if (!existing) {
      return NextResponse.json({ ok: false, error: "Request not found" }, { status: 404 });
    }
    if (existing.vendorId !== vendorId) {
      return NextResponse.json({ ok: false, error: "Forbidden" }, { status: 403 });
    }

    const updated = await prisma.evidenceRequest.update({
      where: { id: requestId },
      data: {
        status: "SUBMITTED",
        // We keep notes out of the DB for now (you can add submissionNotes in Phase 322 if desired)
        updatedAt: new Date(),
      } as any,
    });

    return NextResponse.json({ ok: true, request: updated, notesStored: false, notes });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Failed to submit evidence request" },
      { status: 500 }
    );
  }
}
