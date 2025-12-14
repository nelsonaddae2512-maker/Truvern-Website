// app/api/assessments/export/route.ts
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

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);

    const vendorIdParam = searchParams.get("vendorId");

    const where: any = {};
    if (vendorIdParam) {
      const parsed = Number(vendorIdParam);
      if (!Number.isNaN(parsed)) {
        where.vendorId = parsed;
      }
    }

    const assessments = (await prisma.assessment.findMany({
      where,
      orderBy: { createdAt: "desc" },
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    })) as any[];

    const headers = [
      "vendor",
      "vendorId",
      "assessmentId",
      "score",
      "confidentialityScore",
      "integrityScore",
      "availabilityScore",
      "createdAt"
    ];

    const rows = assessments.map((a) => {
      const vendorName = a.vendor?.name ?? "";
      const vendorId = a.vendorId ?? a.vendor?.id ?? "";
      const assessmentId = a.id;

      const score =
        typeof a.score === "number" ? a.score : "";
      const confidentialityScore =
        typeof a.confidentialityScore === "number" ? a.confidentialityScore : "";
      const integrityScore =
        typeof a.integrityScore === "number" ? a.integrityScore : "";
      const availabilityScore =
        typeof a.availabilityScore === "number" ? a.availabilityScore : "";

      const createdAt =
        a.createdAt instanceof Date
          ? a.createdAt.toISOString()
          : a.createdAt
          ? new Date(a.createdAt).toISOString()
          : "";

      return [
        vendorName,
        vendorId,
        assessmentId,
        score,
        confidentialityScore,
        integrityScore,
        availabilityScore,
        createdAt
      ];
    });

    const csvLines = [
      headers.join(","),
      ...rows.map((row) => row.map(escapeCsv).join(",")),
    ];

    const csv = csvLines.join("\r\n");
    const today = new Date().toISOString().slice(0, 10);
    const suffix = vendorIdParam ? `-vendor-${vendorIdParam}` : "";

    return new NextResponse(csv, {
      status: 200,
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": `attachment; filename="truvern-assessments${suffix}-${today}.csv"`,
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    console.error("Error exporting assessments CSV", error);
    return NextResponse.json(
      { error: "Failed to export assessments CSV" },
      { status: 500 }
    );
  }
}
