// app/api/issues/[id]/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { computeDueAt, IssueSeverity } from "@/lib/issue-sla";

export const runtime = "nodejs";

type Ctx = { params: { id: string } } | { params: Promise<{ id: string }> };

async function getId(ctx: any) {
  const p = ctx?.params;
  if (!p) return null;
  if (typeof p.then === "function") {
    const resolved = await p;
    return resolved?.id ?? null;
  }
  return p?.id ?? null;
}

export async function GET(_req: NextRequest, ctx: Ctx) {
  const idStr = await getId(ctx);
  const issueId = Number(idStr);

  if (!Number.isFinite(issueId)) {
    return NextResponse.json({ ok: false, error: "Invalid id" }, { status: 400 });
  }

  const issue = await prisma.issue.findUnique({
    where: { id: issueId },
    include: {
      vendor: { select: { id: true, name: true } },
      assessment: { select: { id: true, status: true, score: true } },
      assignedTo: { select: { id: true, name: true, email: true } },
      createdBy: { select: { id: true, name: true, email: true } },
      events: { orderBy: { createdAt: "desc" } },
    },
  });

  if (!issue) {
    return NextResponse.json({ ok: false, error: "Not found" }, { status: 404 });
  }

  return NextResponse.json({ ok: true, issue });
}

export async function PATCH(req: NextRequest, ctx: Ctx) {
  const idStr = await getId(ctx);
  const issueId = Number(idStr);

  if (!Number.isFinite(issueId)) {
    return NextResponse.json({ ok: false, error: "Invalid id" }, { status: 400 });
  }

  const body = await req.json().catch(() => ({}));
  const {
    status,
    severity,
    assignedToId,
    dueAt,
    title,
    description,
    comment,
  } = body ?? {};

  const existing = await prisma.issue.findUnique({
    where: { id: issueId },
    select: {
      id: true,
      status: true,
      severity: true,
      assignedToId: true,
      dueAt: true,
      title: true,
      description: true,
      openedAt: true,
    },
  });

  if (!existing) {
    return NextResponse.json({ ok: false, error: "Not found" }, { status: 404 });
  }

  const data: any = {};
  const events: any[] = [];

  if (typeof title === "string" && title.trim() && title.trim() !== existing.title) {
    data.title = title.trim();
    events.push({ type: "TITLE_CHANGE", payload: { from: existing.title, to: data.title } });
  }

  if (typeof description === "string" && description !== (existing.description ?? "")) {
    data.description = description;
    events.push({ type: "DESCRIPTION_CHANGE", payload: { updated: true } });
  }

  if (typeof status === "string" && status !== existing.status) {
    data.status = status;
    events.push({ type: "STATUS_CHANGE", payload: { from: existing.status, to: status } });

    if (status === "RESOLVED" && !existing.dueAt) {
      // no-op; just being safe
    }
    if (status === "RESOLVED") {
      data.closedAt = new Date();
    } else if (existing.closedAt) {
      data.closedAt = null;
    }
  }

  if (typeof severity === "string" && severity !== existing.severity) {
    data.severity = severity;
    events.push({ type: "SEVERITY_CHANGE", payload: { from: existing.severity, to: severity } });

    // Auto-reset dueAt if not explicitly provided
    if (!dueAt) {
      const nextDue = computeDueAt(severity as IssueSeverity, existing.openedAt);
      data.dueAt = nextDue;
      events.push({ type: "DUE_DATE_AUTO", payload: { dueAt: nextDue.toISOString() } });
    }
  }

  if (assignedToId === null || assignedToId === undefined || assignedToId === "") {
    if (existing.assignedToId != null) {
      data.assignedToId = null;
      events.push({ type: "ASSIGNMENT", payload: { from: existing.assignedToId, to: null } });
    }
  } else {
    const nextAssigned = Number(assignedToId);
    if (Number.isFinite(nextAssigned) && nextAssigned !== existing.assignedToId) {
      data.assignedToId = nextAssigned;
      events.push({ type: "ASSIGNMENT", payload: { from: existing.assignedToId, to: nextAssigned } });
    }
  }

  if (typeof dueAt === "string" && dueAt) {
    const parsed = new Date(dueAt);
    if (!Number.isNaN(parsed.getTime())) {
      data.dueAt = parsed;
      events.push({ type: "DUE_DATE_SET", payload: { dueAt: parsed.toISOString() } });
    }
  }

  if (typeof comment === "string" && comment.trim()) {
    events.push({ type: "COMMENT", payload: { text: comment.trim() } });
  }

  const updated = await prisma.issue.update({
    where: { id: issueId },
    data: {
      ...data,
      events: events.length ? { create: events } : undefined,
    } as any,
    include: {
      vendor: { select: { id: true, name: true } },
      assessment: { select: { id: true, status: true, score: true } },
      assignedTo: { select: { id: true, name: true, email: true } },
      createdBy: { select: { id: true, name: true, email: true } },
      events: { orderBy: { createdAt: "desc" } },
    },
  });

  return NextResponse.json({ ok: true, issue: updated });
}
