// app/api/issues/[id]/comment/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { getCurrentOrgId } from "@/lib/current-org";

export async function POST(
  req: NextRequest,
  { params }: { params: Promise<{ id: string }> | { id: string } }
) {
  try {
    const orgId = await getCurrentOrgId();
    if (!orgId) {
      return NextResponse.json({ error: "No org context" }, { status: 401 });
    }

    const { id: rawId } = await Promise.resolve(params);
    const id = Number(String(rawId).match(/\d+/)?.[0]);
    if (!Number.isFinite(id)) {
      return NextResponse.json({ error: "Invalid issue id" }, { status: 400 });
    }

    const body = await req.json().catch(() => ({}));
    const comment = String(body?.comment || "").trim();
    const by = String(body?.by || "").trim();

    if (!comment) {
      return NextResponse.json({ error: "Comment is required" }, { status: 400 });
    }

    // Ensure the issue exists and is in org scope
    const issue = await prisma.issue.findFirst({
      where: { id, organizationId: orgId },
      select: { id: true },
    });

    if (!issue) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }

    const event = await prisma.issueEvent.create({
      data: {
        issueId: id,
        type: "COMMENT",
        payload: {
          by: by || "user",
          comment,
        },
      },
      select: { id: true, createdAt: true },
    });

    // bump updatedAt (optional, but nice for lists)
    await prisma.issue.update({
      where: { id },
      data: { updatedAt: new Date() },
      select: { id: true },
    });

    return NextResponse.json({ ok: true, event });
  } catch (e: any) {
    return NextResponse.json(
      { error: "Server error", detail: String(e?.message || e) },
      { status: 500 }
    );
  }
}
