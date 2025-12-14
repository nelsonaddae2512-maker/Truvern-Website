// app/api/trust-network/export/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function riskLabel(score: number | null): string {
  if (score == null) return "Unknown";
  if (score >= 80) return "Strong";
  if (score >= 50) return "Moderate";
  return "Weak";
}

export async function GET() {
  const vendors = await prisma.vendor.findMany({
    orderBy: { createdAt: "desc" },
    include: {
      _count: {
        select: {
          assessments: true,
          evidence: true,
        },
      },
    },
  });

  const header = [
    "Vendor ID",
    "Name",
    "Risk score",
    "Risk label",
    "Tier",
    "Assessments",
    "Evidence items",
    "Created at",
  ];

  const rows = vendors.map((v) => {
    const tier = (v as any).tier ?? "";
    const createdAt = v.createdAt.toISOString();
    const risk = riskLabel(v.riskScore ?? null);

    return [
      v.id.toString(),
      `"${v.name.replace(/"/g, '""')}"`,
      v.riskScore == null ? "" : v.riskScore.toString(),
      risk,
      tier,
      v._count.assessments.toString(),
      v._count.evidence.toString(),
      createdAt,
    ].join(",");
  });

  const csv = [header.join(","), ...rows].join("\r\n");

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition":
        'attachment; filename="truvern-trust-network.csv"',
    },
  });
}
