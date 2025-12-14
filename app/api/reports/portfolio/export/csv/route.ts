// app/api/reports/portfolio/export/csv/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function escapeCsv(value: string): string {
  if (value.includes('"') || value.includes(",") || value.includes("\n")) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

export async function GET(_req: NextRequest) {
  try {
    const vendors = await prisma.vendor.findMany({
      orderBy: { createdAt: "asc" },
      include: {
        _count: {
          select: {
            assessments: true,
            evidence: true,
          },
        },
      },
    });

    const alerts = await prisma.vendorRiskAlert.findMany({
      where: { resolvedAt: null },
      select: {
        vendorId: true,
      },
    });

    const alertCounts = new Map<number, number>();
    for (const a of alerts) {
      alertCounts.set(a.vendorId, (alertCounts.get(a.vendorId) ?? 0) + 1);
    }

    const header = [
      "Vendor ID",
      "Vendor name",
      "Risk score",
      "Tier",
      "30d trend",
      "90d trend",
      "Assessments",
      "Evidence items",
      "Open alerts",
      "Created at (ISO)",
    ];

    const rows: string[] = [];
    rows.push(header.map(escapeCsv).join(","));

    for (const v of vendors) {
      const tier = (v as any).tier ?? "";
      const trend30 = (v as any).riskTrend30d ?? "";
      const trend90 = (v as any).riskTrend90d ?? "";
      const alertsForVendor = alertCounts.get(v.id) ?? 0;

      const row = [
        v.id.toString(),
        v.name,
        v.riskScore == null ? "" : v.riskScore.toString(),
        tier,
        trend30,
        trend90,
        v._count.assessments.toString(),
        v._count.evidence.toString(),
        alertsForVendor.toString(),
        v.createdAt.toISOString(),
      ];

      rows.push(row.map((cell) => escapeCsv(cell)).join(","));
    }

    const csv = rows.join("\r\n");

    return new NextResponse(csv, {
      status: 200,
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition":
          'attachment; filename="truvern-portfolio-report.csv"',
      },
    });
  } catch (err) {
    console.error("Error generating portfolio CSV:", err);
    return NextResponse.json(
      { error: "Failed to generate portfolio CSV" },
      { status: 500 }
    );
  }
}
