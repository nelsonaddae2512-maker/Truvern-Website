// app/api/issues/[id]/status/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { getCurrentOrgId } from "@/lib/current-org";

const ALLOWED = new Set(["OPEN", "IN_REVIEW", "RESOLVED", "ACCEPTED_RISK"]);

export async function PATCH(
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
    const nextStatus = String(body?.status || "").toUpperCase();

    if (!ALLOWED.has(nextStatus)) {
      return NextResponse.json(
        { error: "Invalid status", allowed: Array.from(ALLOWED) },
        { status: 400 }
      );
    }

    const issue = await prisma.issue.findFirst({
      where: { id, organizationId: orgId },
      select: { id: true, status: true },
    });

    if (!issue) {
      return NextResponse.json({ error: "Issue not found" }, { status: 404 });
    }

    const now = new Date();
    const prevStatus = String(issue.status || "OPEN");

    const updated = await prisma.issue.update({
      where: { id },
      data: {
        status: nextStatus,
        closedAt:
          nextStatus === "RESOLVED" || nextStatus === "ACCEPTED_RISK"
            ? now
            : null,
      },
      select: {
        id: true,
        status: true,
        severity: true,
        dueAt: true,
        closedAt: true,
        updatedAt: true,
      },
    });

    await prisma.issueEvent.create({
      data: {
        issueId: id,
        type: "STATUS_CHANGE",
        payload: { from: prevStatus, to: nextStatus },
      },
    });

    return NextResponse.json({ ok: true, issue: updated });
  } catch (e: any) {
    return NextResponse.json(
      { error: "Server error", detail: String(e?.message || e) },
      { status: 500 }
    );
  }
}
