// app/api/public/vendor/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const idParam = searchParams.get("id");
    const id = Number(idParam);

    if (!idParam || Number.isNaN(id)) {
      return NextResponse.json({ error: "Invalid vendor id" }, { status: 400 });
    }

    const vendor = await prisma.vendor.findUnique({
      where: { id },
      include: {
        _count: {
          select: {
            assessments: true,
            evidence: true,
          },
        },
        assessments: {
          orderBy: { createdAt: "desc" },
          take: 1,
          select: {
            createdAt: true,
          },
        },
      },
    });

    if (!vendor) {
      return NextResponse.json({ error: "Vendor not found" }, { status: 404 });
    }

    const lastAssessmentAt =
      vendor.assessments && vendor.assessments.length > 0
        ? vendor.assessments[0].createdAt
        : null;

    return NextResponse.json({
      vendor: {
        id: vendor.id,
        name: vendor.name,
        riskScore: vendor.riskScore,
        createdAt: vendor.createdAt,
        assessmentsCount: vendor._count.assessments,
        evidenceCount: vendor._count.evidence,
        lastAssessmentAt,
      },
    });
  } catch (err) {
    console.error("Error in /api/public/vendor:", err);
    return NextResponse.json(
      { error: "Internal error loading vendor" },
      { status: 500 }
    );
  }
}
