import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

function param(url: URL, seg: string) {
  const p = url.pathname.split("/").filter(Boolean);
  const i = p.indexOf(seg);
  return i < 0 ? null : p[i + 1];
}

// GET all assessments for vendor
export async function GET(req: NextRequest) {
  const vendorId = param(req.nextUrl, "vendors");
  if (!vendorId) return NextResponse.json({ error: "Missing vendor ID" }, { status: 400 });

  try {
    const list = await prisma.assessment.findMany({
      where: { vendorId: Number(vendorId) },
      orderBy: { createdAt: "desc" },
    });

    return NextResponse.json(list, { status: 200 });
  } catch (err) {
    console.error("GET assessments failed:", err);
    return NextResponse.json({ error: "Failed to load assessments" }, { status: 500 });
  }
}

// POST new assessment
export async function POST(req: NextRequest) {
  const vendorId = param(req.nextUrl, "vendors");
  if (!vendorId) return NextResponse.json({ error: "Missing vendor ID" }, { status: 400 });

  const body = await req.json().catch(() => ({}));

  try {
    const created = await prisma.assessment.create({
      data: {
        vendorId: Number(vendorId),
        score: body.score ?? null,
        riskLevel: body.riskLevel ?? null,
        summary: body.summary ?? null,
      },
    });

    return NextResponse.json(created, { status: 201 });
  } catch (err) {
    console.error("POST assessment failed:", err);
    return NextResponse.json({ error: "Failed to create assessment" }, { status: 500 });
  }
}
