// app/api/issues/[id]/status/route.ts
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

export async function PATCH(req: NextRequest, context: any) {
  try {
    const idRaw = context?.params?.id;
    const id = Number(idRaw);

    if (!idRaw || Number.isNaN(id)) {
      return NextResponse.json(
        { error: "Invalid issue id" },
        { status: 400 }
      );
    }

    let body: any = {};
    try {
      body = await req.json();
    } catch {
      // ignore – will be validated below
    }

    const status = body?.status as string | undefined;
    if (!status) {
      return NextResponse.json(
        { error: "status is required" },
        { status: 400 }
      );
    }

    const updated = await prisma.issue.update({
      where: { id },
      data: { status },
    });

    return NextResponse.json(
      {
        id: updated.id,
        title: updated.title,
        severity: updated.severity,
        status: updated.status,
        dueDate: updated.dueDate,
        vendorId: updated.vendorId,
      },
      { status: 200 }
    );
  } catch (err) {
    console.error("[PATCH /api/issues/[id]/status] error", err);
    return NextResponse.json(
      { error: "Failed to update issue status" },
      { status: 500 }
    );
  }
}
