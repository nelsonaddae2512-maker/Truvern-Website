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

export async function POST(req: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const requestId = Number(id);
    if (!Number.isFinite(requestId)) {
      return NextResponse.json({ ok: false, error: "Invalid request id" }, { status: 400 });
    }

    // Determine vendor identity
    let vendorId: number | undefined;

    if (!devBypassEnabled()) {
      const { userId } = auth();
      if (!userId) return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });

      const user = await currentUser();
      const vendorIdRaw = (user?.publicMetadata as any)?.vendorId;
      vendorId =
        typeof vendorIdRaw === "number"
          ? vendorIdRaw
          : typeof vendorIdRaw === "string"
          ? Number(vendorIdRaw)
          : undefined;

      if (!Number.isFinite(vendorId as any)) {
        return NextResponse.json({ ok: false, error: "Vendor account not linked" }, { status: 403 });
      }
    } else {
      vendorId = Number(process.env.TRUVERN_DEV_VENDOR_ID ?? "");
      if (!Number.isFinite(vendorId)) {
        return NextResponse.json({ ok: false, error: "DEV vendorId not set" }, { status: 400 });
      }
    }

    const body = await req.json().catch(() => ({}));
    const notes = body?.notes ? String(body.notes) : null;
    const kind = body?.kind ?? "OTHER";
    const title = body?.title ? String(body.title) : "Evidence submission";

    const er = await prisma.evidenceRequest.findUnique({ where: { id: requestId } });
    if (!er) return NextResponse.json({ ok: false, error: "Request not found" }, { status: 404 });
    if (er.vendorId !== vendorId) {
      return NextResponse.json({ ok: false, error: "Forbidden" }, { status: 403 });
    }

    // Best-effort create Evidence placeholder (works even before S3)
    let createdEvidenceId: number | null = null;
    try {
      const ev: any = await (prisma as any).evidence?.create?.({
        data: {
          vendorId,
          title,
          description: notes,
          kind,
          uploadedAt: new Date(),
        },
        select: { id: true },
      });
      createdEvidenceId = ev?.id ?? null;
    } catch {
      // Evidence schema may differ; we still allow submission.
      createdEvidenceId = null;
    }

    const updated = await prisma.evidenceRequest.update({
      where: { id: requestId },
      data: {
        status: "SUBMITTED",
        evidenceId: createdEvidenceId,
      } as any,
    });

    return NextResponse.json({ ok: true, request: updated, evidenceId: createdEvidenceId });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Failed to submit evidence request" },
      { status: 500 }
    );
  }
}
