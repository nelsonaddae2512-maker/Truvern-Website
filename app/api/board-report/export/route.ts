// app/api/board-report/export/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { computeVendorRiskMap } from "@/lib/risk/vendor-risk";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function csvEscape(value: any) {
  if (value == null) return "";
  const s = String(value);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}
function toCsv(rows: any[][]) {
  return rows.map((r) => r.map(csvEscape).join(",")).join("\n");
}

function riskLabel(score: number) {
  if (score >= 80) return "Low";
  if (score >= 60) return "Moderate";
  if (score >= 40) return "High";
  return "Critical";
}

function bucketKey(score: number): "LOW" | "MODERATE" | "HIGH" | "CRITICAL" {
  if (score >= 80) return "LOW";
  if (score >= 60) return "MODERATE";
  if (score >= 40) return "HIGH";
  return "CRITICAL";
}

export async function GET() {
  const vendors = await prisma.vendor.findMany({
    orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
    take: 500,
    select: {
      id: true,
      name: true,
      updatedAt: true,
      category: true as any,
    } as any,
  });

  const list = vendors as any[];
  const vendorIds = list.map((v) => v.id);
  const riskMap = await computeVendorRiskMap(vendorIds);

  // Detailed header
  const header = [
    "Vendor ID",
    "Vendor Name",
    "Category",
    "Risk Score",
    "Risk Label",
    "Open",
    "Accepted",
    "Resolved",
    "Open Critical",
    "Open High",
    "Open Medium",
    "Open Low",
    "Open Info",
    "Top Drivers",
    "Last Updated",
  ];

  // Build detail rows
  const detailRows: any[][] = list.map((v) => {
    const r =
      riskMap.get(v.id) ??
      ({
        score: 100,
        open: 0,
        accepted: 0,
        resolved: 0,
        bySeverityOpen: { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 },
        topDrivers: [],
      } as any);

    const score = Number.isFinite(r.score) ? r.score : 100;

    return [
      v.id,
      v.name ?? "",
      v.category ?? "",
      score,
      riskLabel(score),
      r.open ?? 0,
      r.accepted ?? 0,
      r.resolved ?? 0,
      r.bySeverityOpen?.CRITICAL ?? 0,
      r.bySeverityOpen?.HIGH ?? 0,
      r.bySeverityOpen?.MEDIUM ?? 0,
      r.bySeverityOpen?.LOW ?? 0,
      r.bySeverityOpen?.INFO ?? 0,
      (r.topDrivers ?? []).join("; "),
      v.updatedAt instanceof Date
        ? v.updatedAt.toISOString()
        : String(v.updatedAt ?? ""),
    ];
  });

  // Sort worst-risk first (Risk Score column index 3)
  detailRows.sort((a, b) => Number(a[3]) - Number(b[3]));

  // ---- Summary calculations (from the same computed data) ----
  const totalVendors = detailRows.length;

  let sumScore = 0;
  const buckets = { LOW: 0, MODERATE: 0, HIGH: 0, CRITICAL: 0 };
  const sevTotals = { CRITICAL: 0, HIGH: 0, MEDIUM: 0, LOW: 0, INFO: 0 };
  let openTotal = 0;
  let acceptedTotal = 0;
  let resolvedTotal = 0;

  for (const row of detailRows) {
    const score = Number(row[3]) || 0;
    sumScore += score;
    buckets[bucketKey(score)] += 1;

    // Open/Accepted/Resolved indexes
    openTotal += Number(row[5]) || 0;
    acceptedTotal += Number(row[6]) || 0;
    resolvedTotal += Number(row[7]) || 0;

    // Severity totals indexes
    sevTotals.CRITICAL += Number(row[8]) || 0;
    sevTotals.HIGH += Number(row[9]) || 0;
    sevTotals.MEDIUM += Number(row[10]) || 0;
    sevTotals.LOW += Number(row[11]) || 0;
    sevTotals.INFO += Number(row[12]) || 0;
  }

  const avgScore =
    totalVendors > 0 ? Math.round(sumScore / totalVendors) : 100;

  const generatedAt = new Date().toISOString();

  // Summary rows (2-column "Key,Value" style)
  const summaryRows: any[][] = [
    ["Truvern Board Packet (CSV)"],
    ["Generated At", generatedAt],
    ["Vendors", totalVendors],
    ["Portfolio Avg Score", avgScore],
    ["Risk Buckets (count)", `Low ${buckets.LOW} | Moderate ${buckets.MODERATE} | High ${buckets.HIGH} | Critical ${buckets.CRITICAL}`],
    ["Totals", `Open ${openTotal} | Accepted ${acceptedTotal} | Resolved ${resolvedTotal}`],
    ["Open Severity Totals", `C ${sevTotals.CRITICAL} | H ${sevTotals.HIGH} | M ${sevTotals.MEDIUM} | L ${sevTotals.LOW} | I ${sevTotals.INFO}`],
    [], // blank line
  ];

  const csv = toCsv([...summaryRows, header, ...detailRows]);

  const filename = `truvern-board-packet-${new Date().toISOString().slice(0, 10)}.csv`;

  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "Cache-Control": "no-store",
    },
  });
}
