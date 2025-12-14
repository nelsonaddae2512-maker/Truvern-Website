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

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await params;
    const requestId = Number(id);
    if (Number.isNaN(requestId)) {
      return NextResponse.json({ error: "Invalid request id" }, { status: 400 });
    }

    const body = await req.json().catch(() => ({}));

    // Accept BOTH shapes:
    //  A) { evidenceIds: number[] }  (Phase 322 style)
    //  B) { items: [{title,fileUrl,kind}] } (your current vendor submit component)
    const evidenceIdsFromBody: number[] = Array.isArray(body?.evidenceIds)
      ? body.evidenceIds
          .map((n: any) => Number(n))
          .filter((n: number) => !Number.isNaN(n))
      : [];

    const items = cleanItems(body?.items);

    const submittedBy =
      typeof body?.submittedBy === "string" ? body.submittedBy : null;

    // Ensure request exists (+ vendor/org for creating evidence rows)
    const reqRow = await prisma.evidenceRequest.findUnique({
      where: { id: requestId },
      select: {
        id: true,
        status: true,
        vendorId: true,
        organizationId: true,
      },
    });

    if (!reqRow) return NextResponse.json({ error: "Not found" }, { status: 404 });

    // Only allow submit/resubmit if OPEN or REJECTED
    if (!["OPEN", "REJECTED"].includes(String(reqRow.status))) {
      return NextResponse.json(
        { error: "Request is not open for submission" },
        { status: 409 }
      );
    }

    // If caller didn't provide evidenceIds, we can create Evidence rows from items
    if (evidenceIdsFromBody.length === 0 && items.length === 0) {
      return NextResponse.json(
        { error: "Provide either evidenceIds[] or items[]" },
        { status: 400 }
      );
    }

    const result = await prisma.$transaction(async (tx) => {
      // 1) Create a new iteration (the audit unit)
      const iter = await tx.evidenceRequestIteration.create({
        data: {
          evidenceRequestId: requestId,
          status: "SUBMITTED" as any,
          submittedBy: submittedBy ?? undefined,
          submittedAt: new Date(),
        },
        select: { id: true },
      });

      // 2) Determine evidenceIds:
      let evidenceIds: number[] = evidenceIdsFromBody;

      // Create evidence from items if needed
      if (evidenceIds.length === 0 && items.length > 0) {
        // If orgId is nullable, Evidence requires organizationId (non-null in your schema)
        // So we must have orgId to create evidence.
        if (!reqRow.organizationId) {
          throw new Error(
            "Cannot create evidence: evidence request has no organizationId."
          );
        }

        const created = await Promise.all(
          items.map((it) =>
            tx.evidence.create({
              data: {
                vendorId: reqRow.vendorId,
                organizationId: reqRow.organizationId!,
                evidenceRequestId: requestId,
                iterationId: iter.id,
                title: it.title,
                fileUrl: it.fileUrl,
                kind: it.kind as any, // EvidenceKind enum
                uploadedAt: new Date(),
              },
              select: { id: true },
            })
          )
        );

        evidenceIds = created.map((c) => c.id);
      } else {
        // 3) Attach existing evidence to this iteration + request
        // (Make sure they are linked to this request for consistency)
        await tx.evidence.updateMany({
          where: { id: { in: evidenceIds } },
          data: {
            iterationId: iter.id,
            evidenceRequestId: requestId,
          },
        });
      }

      // 4) Update the request status
      await tx.evidenceRequest.update({
        where: { id: requestId },
        data: {
          status: "SUBMITTED" as any,
          submittedAt: new Date(),
        } as any,
      });

      return { iterationId: iter.id, evidenceIds };
    });

    return NextResponse.json({
      ok: true,
      iterationId: result.iterationId,
      evidenceIds: result.evidenceIds,
    });
  } catch (err: any) {
    return NextResponse.json(
      { error: err?.message ?? "Unknown error" },
      { status: 500 }
    );
  }
}
