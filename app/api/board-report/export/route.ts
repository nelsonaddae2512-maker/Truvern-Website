import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function computeCIA(riskScore: number | null) {
  if (riskScore == null) {
    return {
      confidentiality: 0,
      integrity: 0,
      availability: 0,
      overall: "Unknown",
    };
  }

  const base = clamp(riskScore, 0, 100);
  const confidentiality = clamp(base, 0, 100);
  const integrity = clamp(Math.round(base * 0.9), 0, 100);
  const availability = clamp(Math.round(base * 0.95), 0, 100);

  let overall = "Moderate";
  if (base >= 80) overall = "Strong";
  else if (base < 50) overall = "Weak";

  return { confidentiality, integrity, availability, overall };
}

export async function GET() {
  const vendors = await prisma.vendor.findMany({
    include: {
      _count: {
        select: {
          assessments: true,
          evidence: true,
        },
      },
    },
    orderBy: { id: "asc" },
  });

  const totalVendors = vendors.length;
  const totalAssessments = vendors.reduce(
    (sum, v) => sum + v._count.assessments,
    0
  );
  const totalEvidence = vendors.reduce(
    (sum, v) => sum + v._count.evidence,
    0
  );
  const avgRisk =
    totalVendors > 0
      ? Math.round(
          vendors.reduce((sum, v) => sum + (v.riskScore ?? 0), 0) /
            totalVendors
        )
      : 0;

  const headerSummary = [
    `Total vendors: ${totalVendors}`,
    `Average risk score: ${avgRisk}`,
    `Total assessments: ${totalAssessments}`,
    `Total evidence items: ${totalEvidence}`,
  ].join(",");

  const header = [
    "Vendor ID",
    "Name",
    "Risk Score",
    "CIA: Confidentiality",
    "CIA: Integrity",
    "CIA: Availability",
    "Overall Rating",
    "Assessments",
    "Evidence Items",
  ];

  const rows = vendors.map((v) => {
    const cia = computeCIA(v.riskScore ?? null);

    return [
      v.id,
      `"${v.name.replace(/"/g, '""')}"`,
      v.riskScore ?? "",
      cia.confidentiality,
      cia.integrity,
      cia.availability,
      cia.overall,
      v._count.assessments,
      v._count.evidence,
    ].join(",");
  });

  // Compute Top 10 Riskiest Vendors
  const risky = [...vendors]
    .sort((a, b) => (a.riskScore ?? 999) - (b.riskScore ?? 999))
    .slice(0, 10);

  const riskyHeader = "Top 10 Riskiest Vendors";
  const riskyRows = risky.map((v) => {
    const cia = computeCIA(v.riskScore ?? null);
    return [
      v.id,
      `"${v.name}"`,
      v.riskScore ?? "",
      cia.overall,
    ].join(",");
  });

  const csv = [
    headerSummary,
    "",
    header.join(","),
    ...rows,
    "",
    riskyHeader,
    "Vendor ID,Name,Risk Score,Overall Rating",
    ...riskyRows,
  ].join("\r\n");

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition":
        'attachment; filename="truvern-board-report.csv"',
    },
  });
}
