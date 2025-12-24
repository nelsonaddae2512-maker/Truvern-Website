// app/api/vendor/evidence-requests/[id]/submit/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

type Item = {
  title?: string;
  fileUrl?: string;
  kind?: string;
};

function cleanItems(items: any): Required<Pick<Item, "title" | "fileUrl" | "kind">>[] {
  if (!Array.isArray(items)) return [];
  return items
    .map((x) => ({
      title: typeof x?.title === "string" ? x.title.trim() : "",
      fileUrl: typeof x?.fileUrl === "string" ? x.fileUrl.trim() : "",
      kind: typeof x?.kind === "string" ? x.kind : "OTHER",
    }))
    .filter((x) => x.title && x.fileUrl);
}

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const { id } = await params;
    const requestId = Number(id);
    if (!Number.isFinite(requestId)) {
      return NextResponse.json({ ok: false, error: "Invalid request id" }, { status: 400 });
    }

    const body = await req.json().catch(() => ({} as any));
    const items = cleanItems(body?.items);

    if (!items.length) {
      return NextResponse.json({ ok: false, error: "At least one valid item is required" }, { status: 400 });
    }

    const now = new Date();

    // Load current request + latest iteration (for continuity if needed)
    const existing = await prisma.evidenceRequest.findUnique({
      where: { id: requestId },
      include: { iterations: { orderBy: { id: "desc" } as any, take: 1 } as any },
    } as any);

    if (!existing) {
      return NextResponse.json({ ok: false, error: "Evidence request not found" }, { status: 404 });
    }

    // Resubmission should clear old review info
    const updated = await prisma.$transaction(async (tx) => {
      // Create iteration
      const iter = await (tx as any).evidenceRequestIteration.create({
        data: {
          evidenceRequestId: requestId,
          status: "SUBMITTED",
          submittedAt: now,
          reviewedAt: null,
          reviewNote: null,
          items,
        },
      });

      // Update root request
      const req2 = await tx.evidenceRequest.update({
        where: { id: requestId },
        data: {
          status: "SUBMITTED",
          submittedAt: now,
          reviewedAt: null,
          reviewNote: null,
          // If you store evidenceId, keep as-is here; submission doesn’t attach evidence directly in this endpoint.
        } as any,
      });

      return { iter, req2 };
    });

    return NextResponse.json({
      ok: true,
      requestId,
      status: (updated.req2 as any).status,
      submittedAt: (updated.req2 as any).submittedAt,
      iterationId: (updated.iter as any).id,
      itemsCount: items.length,
    });
  } catch (e: any) {
    return NextResponse.json({ ok: false, error: e?.message || "Submit failed" }, { status: 500 });
  }
}
