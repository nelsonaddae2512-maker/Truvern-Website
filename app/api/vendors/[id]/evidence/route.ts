import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

interface RouteParams {
  params: { id: string };
}

export async function GET(_req: NextRequest, { params }: RouteParams) {
  const vendorId = Number(params.id);
  if (!Number.isInteger(vendorId)) {
    return NextResponse.json({ error: "Invalid vendor id" }, { status: 400 });
  }

  const evidence = await prisma.evidence.findMany({
    where: { vendorId },
    orderBy: { uploadedAt: "desc" },
    select: {
      id: true,
      filename: true,
      mimeType: true,
      size: true,
      uploadedAt: true,
      notes: true,
    },
  });

  return NextResponse.json(evidence, { status: 200 });
}
