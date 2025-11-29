// app/api/issues/[issueId]/status/route.ts
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

// Run on the Node.js runtime
export const runtime = "nodejs";

/**
 * PATCH /api/issues/[issueId]/status
 * Body: { status: "Open" | "In progress" | "Closed" }
 */
export async function PATCH(
  req: NextRequest,
  context: { params: { issueId: string } }
) {
  try {
    const { issueId } = context.params;
    const id = Number(issueId);

    if (Number.isNaN(id)) {
      return NextResponse.json(
        { error: "Invalid issue id" },
        { status: 400 }
      );
    }

    const body = await req.json().catch(() => null) as { status?: string } | null;

    if (!body || !body.status) {
      return NextResponse.json(
        { error: "Missing status in request body" },
        { status: 400 }
      );
    }

    const updated = await prisma.issue.update({
      where: { id },
      data: { status: body.status },
    });

    return NextResponse.json(
      {
        id: updated.id,
        title: updated.title,
        severity: updated.severity,
        status: updated.status,
        dueDate: updated.dueDate,
      },
      { status: 200 }
    );
  } catch (err) {
    console.error("Error updating issue status:", err);
    return NextResponse.json(
      { error: "Failed to update issue status" },
      { status: 500 }
    );
  }
}
