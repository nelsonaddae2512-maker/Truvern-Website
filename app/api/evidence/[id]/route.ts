// app/api/evidence/[id]/route.ts
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

type RouteContext = {
  params: {
    id: string;
  };
};

// Optional: GET single evidence (handy for debugging)
export async function GET(_req: Request, { params }: RouteContext) {
  const id = Number(params.id);
  if (!Number.isInteger(id)) {
    return NextResponse.json({ error: "Invalid evidence id" }, { status: 400 });
  }

  try {
    const evidence = await prisma.evidence.findUnique({
      where: { id },
    });

    if (!evidence) {
      return NextResponse.json({ error: "Evidence not found" }, { status: 404 });
    }

    return NextResponse.json({ evidence });
  } catch (err) {
    console.error("[/api/evidence/[id]] GET error:", err);
    return NextResponse.json(
      { error: "Failed to load evidence" },
      { status: 500 }
    );
  }
}

// DELETE /api/evidence/:id
export async function DELETE(_req: Request, { params }: RouteContext) {
  const id = Number(params.id);
  if (!Number.isInteger(id)) {
    return NextResponse.json({ error: "Invalid evidence id" }, { status: 400 });
  }

  try {
    // Ensure it exists so we can return a useful 404
    const existing = await prisma.evidence.findUnique({
      where: { id },
      select: { id: true },
    });

    if (!existing) {
      return NextResponse.json({ error: "Evidence not found" }, { status: 404 });
    }

    await prisma.evidence.delete({
      where: { id },
    });

    return NextResponse.json({ success: true }, { status: 200 });
  } catch (err) {
    console.error("[/api/evidence/[id]] DELETE error:", err);
    return NextResponse.json(
      { error: "Failed to delete evidence" },
      { status: 500 }
    );
  }
}
