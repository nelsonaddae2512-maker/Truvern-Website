import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { EvidenceRequestStatus, Prisma } from "@prisma/client";

export const runtime = "nodejs";

function pickCreateData(input: any) {
  // Use Prisma DMMF to only set fields that exist in your schema (safe across schema tweaks)
  const m = Prisma.dmmf.datamodel.models.find((x) => x.name === "EvidenceRequest");
  const fields = new Set((m?.fields ?? []).map((f) => f.name));

  const data: any = {};
  if (fields.has("vendorId")) data.vendorId = Number(input.vendorId);
  if (fields.has("label")) data.label = String(input.label ?? "Evidence Request");
  if (fields.has("status")) data.status = EvidenceRequestStatus.OPEN;

  // optional fields if they exist
  if (fields.has("kind") && input.kind != null) data.kind = input.kind;
  if (fields.has("notes") && input.notes != null) data.notes = String(input.notes);
  if (fields.has("requestedAt")) data.requestedAt = new Date();

  return data;
}

export async function POST(
  req: Request,
  ctx: { params: Promise<{ id: string }> }
) {
  try {
    const { id } = await ctx.params;
    const vendorId = Number(id);
    if (!Number.isFinite(vendorId)) {
      return NextResponse.json({ ok: false, error: "Invalid vendor id" }, { status: 400 });
    }

    const body = await req.json().catch(() => ({}));
    const label = body?.label ?? body?.title ?? "Evidence Request";

    const created = await prisma.evidenceRequest.create({
      data: pickCreateData({ vendorId, label, kind: body?.kind, notes: body?.notes }),
      select: { id: true, vendorId: true, label: true, status: true } as any,
    });

    return NextResponse.json({ ok: true, request: created });
  } catch (err: any) {
    console.error(err);
    return NextResponse.json(
      { ok: false, error: "Create failed", debug: err?.message ?? String(err) },
      { status: 500 }
    );
  }
}
