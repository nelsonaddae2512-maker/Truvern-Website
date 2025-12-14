// app/api/trust-network-export/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function riskBand(score: number | null | undefined): string {
  if (score == null) return "Unknown";
  if (score >= 80) return "Low";
  if (score >= 60) return "Medium";
  return "High";
}

// Simple CSV escaping helper
function safe(value: string | number | null | undefined): string {
  if (value === null || value === undefined) return "";
  const s = String(value);
  if (s.includes(",") || s.includes('"') || s.includes("\n")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

export async function GET(_req: NextRequest) {
  const vendorsRaw = await prisma.vendor.findMany({
    orderBy: { name: "asc" },
    include: {
      _count: {
        select: {
          assessments: true,
          evidence: true,
        },
      },
    },
  });

  const vendors = vendorsRaw as any[];

  const rows: string[] = [];

  // Header
  rows.push(
    [
      "Vendor",
      "HealthScore",
      "RiskBand",
      "Assessments",
      "EvidenceItems",
      "AddedToTruvern",
      "Summary",
    ].join(",")
  );

  // Data rows
  for (const v of vendors) {
    const score: number | null = v.riskScore ?? null;
    const band = riskBand(score);
    const assessments = v._count?.assessments ?? 0;
    const evidenceCount = v._count?.evidence ?? 0;
    const createdAt = v.createdAt as Date | string | null;
    const createdStr = createdAt ? new Date(createdAt).toISOString() : "";
    const summary: string =
      (v.summary as string | null | undefined) ??
      "Vendor listed on Truvern Trust Network.";

    rows.push(
      [
        safe(v.name),
        safe(score ?? 0),
        safe(band),
        safe(assessments),
        safe(evidenceCount),
        safe(createdStr),
        safe(summary),
      ].join(",")
    );
  }

  const csv = rows.join("\r\n");

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition":
        'attachment; filename="truvern-trust-network.csv"',
    },
  });
}
