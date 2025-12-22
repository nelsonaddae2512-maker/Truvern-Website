// app/api/evidence-requests/[id]/review/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { resolveActor } from "@/lib/actor";
import { requireOrgActor } from "@/lib/guards";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function json(status: number, body: any) {
  return NextResponse.json(body, { status });
}

async function safeJson(req: NextRequest) {
  try {
    return await req.json();
  } catch {
    return null;
  }
}

export async function POST(req: NextRequest, ctx: any) {
  try {
    const actor = await resolveActor(req);
    if (!actor) return json(401, { ok: false, error: "Unauthorized" });

    const orgId = requireOrgActor(actor);

    const id = Number(ctx?.params?.id);
    if (!Number.isFinite(id)) return json(400, { ok: false, error: "Invalid id" });

    const body = await safeJson(req);
    const action = String(body?.action ?? body?.status ?? "").toUpperCase().trim();

    // expected actions: APPROVE / REJECT (you can extend later)
    const nextStatus =
      action === "APPROVE" || action === "APPROVED"
        ? "APPROVED"
        : action === "REJECT" || action === "REJECTED"
        ? "REJECTED"
        : null;

    if (!nextStatus) {
      return json(400, { ok: false, error: "Invalid action. Use APPROVE or REJECT." });
    }

    const existing = await prisma.evidenceRequest.findUnique({
      where: { id },
      select: { id: true, organizationId: true, vendorId: true, status: true },
    });

    if (!existing) return json(404, { ok: false, error: "Not found" });
    if (!existing.organizationId || existing.organizationId !== orgId) {
      return json(403, { ok: false, error: "Forbidden" });
    }

    const updated = await prisma.evidenceRequest.update({
      where: { id },
      data: { status: nextStatus as any },
      select: { id: true, vendorId: true, organizationId: true, status: true },
    });

    return json(200, { ok: true, request: updated });
  } catch (e: any) {
    const status = Number(e?.status) || 500;
    const msg = status === 500 ? "Internal error" : String(e?.message || "Error");
    if (status === 500) console.error("Evidence request review API error", e);
    return json(status, { ok: false, error: msg });
  }
}
