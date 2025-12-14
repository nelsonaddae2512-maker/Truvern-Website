// app/api/evidence/export/route.ts
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

    const evidenceItems = (await prisma.evidence.findMany({
      where,
      orderBy: { uploadedAt: "desc" },
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
      "evidenceId",
      "title",
      "kind",
      "uploadedAt",
      "description",
    ];

    const rows = evidenceItems.map((e) => {
      const vendorName = e.vendor?.name ?? "";
      const vendorId = e.vendorId ?? e.vendor?.id ?? "";
      const evidenceId = e.id;
      const title = e.title ?? "";
      const kind = e.kind ?? "";
      const description = e.description ?? "";

      const uploadedAt =
        e.uploadedAt instanceof Date
          ? e.uploadedAt.toISOString()
          : e.uploadedAt
          ? new Date(e.uploadedAt).toISOString()
          : "";

      return [vendorName, vendorId, evidenceId, title, kind, uploadedAt, description];
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
        "Content-Disposition": `attachment; filename="truvern-evidence${suffix}-${today}.csv"`,
        "Cache-Control": "no-store",
      },
    });
  } catch (error) {
    console.error("Error exporting evidence CSV", error);
    return NextResponse.json(
      { error: "Failed to export evidence CSV" },
      { status: 500 }
    );
  }
}
