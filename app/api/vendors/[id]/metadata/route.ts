import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

function param(url: URL, segment: string): string | null {
  const p = url.pathname.split("/").filter(Boolean);
  const i = p.indexOf(segment);
  return i === -1 ? null : p[i + 1];
}

export async function PATCH(req: NextRequest) {
  const url = req.nextUrl;
  const id = param(url, "vendors");

  if (!id) return NextResponse.json({ error: "Missing vendor ID" }, { status: 400 });

  const body = await req.json().catch(() => ({}));

  try {
    const updated = await prisma.vendor.update({
      where: { id: Number(id) },
      data: {
        ...(body.tier !== undefined ? { tier: body.tier } : {}),
        ...(body.criticality !== undefined ? { criticality: body.criticality } : {}),
        ...(body.category !== undefined ? { category: body.category } : {}),
        ...(body.primaryContactName !== undefined
          ? { primaryContactName: body.primaryContactName }
          : {}),
        ...(body.primaryContactEmail !== undefined
          ? { primaryContactEmail: body.primaryContactEmail }
          : {}),
      },
    });

    return NextResponse.json(updated, { status: 200 });
  } catch (err) {
    console.error("Metadata update failed:", err);
    return NextResponse.json({ error: "Update failed" }, { status: 500 });
  }
}
