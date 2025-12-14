// app/api/board-report/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function escapeCsv(value: unknown): string {
  if (value == null) return "";
  const s = String(value);
  if (s.includes('"') || s.includes(",") || s.includes("\n") || s.includes("\r")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function riskBand(score: number | null | undefined): string {
  if (score == null || Number.isNaN(Number(score))) return "Unknown";
  const n = Number(score);
  if (n >= 80) return "Low";
  if (n >= 60) return "Medium";
  return "High";
}

function averageOf(values: (number | null | undefined)[]): number | null {
  const nums = values.filter(
    (v) => typeof v === "number" && !Number.isNaN(Number(v))
  ) as number[];
  if (nums.length === 0) return null;
  const sum = nums.reduce((acc, n) => acc + n, 0);
  return Math.round(sum / nums.length);
}

export async function GET(_req: NextRequest) {
  try {
    // Top 10 riskiest vendors by riskScore (lowest scores first)
    const vendors = (await prisma.vendor.findMany({
      orderBy: { riskScore: "asc" },
      take: 10,
      include: {
        _count: {
          select: {
            assessments: true,
            evidence: true,
          },
        },
        evidence: {
          orderBy: { uploadedAt: "desc" },
          take: 1,
          select: {
            uploadedAt: true,
          },
        },
        assessments: {
          select: {
            score: true,
            confidentialityScore: true,
            integrityScore: true,
            availabilityScore: true,
          },
        },
      },
    })) as any[];

    const headers = [
      "vendorName",
      "vendorId",
      "riskScore",
      "riskBand",
      "assessmentsCount",
      "evidenceCount",
      "lastEvidenceUploadedAt",
      "avgAssessmentScore",
      "avgConfidentialityScore",
      "avgIntegrityScore",
      "avgAvailabilityScore"
    ];

    const rows = vendors.map((v) => {
      const riskScore: number | null = v.riskScore ?? null;
      const band = riskBand(riskScore);

      const assessmentsForVendor = (v.assessments ?? []) as any[];
      const avgScore = averageOf(
        assessmentsForVendor.map((a) => a.score as number | null)
      );
      const avgC = averageOf(
        assessmentsForVendor.map(
          (a) => a.confidentialityScore as number | null
        )
      );
      const avgI = averageOf(
        assessmentsForVendor.map((a) => a.integrityScore as number | null)
      );
      const avgA = averageOf(
        assessmentsForVendor.map((a) => a.availabilityScore as number | null)
      );

      const lastEvidenceDate = v.evidence[0]?.uploadedAt ?? null;
      const lastEvidenceIso =
        lastEvidenceDate instanceof Date
          ? lastEvidenceDate.toISOString()
          : lastEvidenceDate
          ? new Date(lastEvidenceDate).toISOString()
          : "";

      return [
        v.name ?? "",
        v.id ?? "",
        riskScore != null ? riskScore : "",
        band,
        v._count?.assessments ?? 0,
        v._count?.evidence ?? 0,
        lastEvidenceIso,
        avgScore != null ? avgScore : "",
        avgC != null ? avgC : "",
        avgI != null ? avgI : "",
        avgA != null ? avgA : ""
      ];
    });

    const csvLines = [
      headers.join(","),
      ...rows.map((row) => row.map(escapeCsv).join(",")),
    ];

    const csv = csvLines.join("\r\n");
    const today = new Date().toISOString().slice(0, 10);

    return new NextResponse(csv, {
      status: 200,
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="truvern-board-report-top10-${today}.csv"`,
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    console.error("Error exporting board report CSV", error);
    return NextResponse.json(
      { error: "Failed to export board report CSV" },
      { status: 500 }
    );
  }
}
