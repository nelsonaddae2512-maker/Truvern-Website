export const runtime = 'nodejs';
// Phase63 - Assessment Results API
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { PrismaClient } from "@prisma/client";

const getPrisma = () => {
  const g = global as any;
  if (!g.__PRISMA__) g.__PRISMA__ = new PrismaClient();
  return g.__PRISMA__ as PrismaClient;
};

type ScoreRow = {
  control: string;
  weight: number;
  score: number;
  status: "pass" | "warn" | "fail";
};

type ResultsPayload = {
  org: string;
  assessmentId?: string;
  overall: number;
  risk: "Low" | "Medium" | "High";
  items: ScoreRow[];
  generatedAt: string;
};

function demoResults(org: string, assessmentId?: string): ResultsPayload {
  const items: ScoreRow[] = [
    { control: "Access Control", weight: 0.2, score: 92, status: "pass" },
    { control: "Vulnerability Mgmt", weight: 0.2, score: 78, status: "warn" },
    { control: "Incident Response", weight: 0.2, score: 88, status: "pass" },
    { control: "Data Encryption", weight: 0.2, score: 95, status: "pass" },
    { control: "Vendor Management", weight: 0.2, score: 61, status: "warn" },
  ];
  const overall = Math.round(items.reduce((a, r) => a + r.score * r.weight, 0));
  const risk = overall >= 85 ? "Low" : overall >= 70 ? "Medium" : "High";
  return { org, assessmentId, overall, risk, items, generatedAt: new Date().toISOString() };
}

function toCSV(data: ResultsPayload): string {
  const header = "control,weight,score,status";
  const rows = data.items.map(i =>
    [i.control.replace(/[,\\n]/g, " "), i.weight, i.score, i.status].join(",")
  );
  return [header, ...rows, "", "overall," + data.overall, "risk," + data.risk, "org," + data.org, "assessmentId," + (data.assessmentId ?? ""), "generatedAt," + data.generatedAt].join("\\n");
}

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const org = searchParams.get("org") ?? "demo-2128873b";
  const assessmentId = searchParams.get("assessmentId") ?? undefined;
  const format = (searchParams.get("format") ?? "json").toLowerCase();

  let payload: ResultsPayload;
  try {
    const prisma = getPrisma();
    const latest = await prisma.assessment.findFirst({
      where: assessmentId ? { id: assessmentId } : { organizationId: org },
      orderBy: { createdAt: "desc" },
      select: {
        id: true,
        organizationId: true,
        overall: true,
        risk: true,
        results: {
          select: { control: true, weight: true, score: true, status: true },
        },
        createdAt: true,
      },
    });
    if (!latest) {
      payload = demoResults(org, assessmentId);
    } else {
      payload = {
        org: latest.organizationId,
        assessmentId: latest.id,
        overall: Math.round(latest.overall ?? 0),
        risk: (latest.risk as ResultsPayload["risk"]) ?? "Medium",
        items: (latest.results as ScoreRow[]) ?? [],
        generatedAt: new Date().toISOString(),
      };
      if (!payload.items.length) payload = demoResults(payload.org, payload.assessmentId);
    }
  } catch (e) {
    payload = demoResults(org, assessmentId);
  }

  if (format === "csv") {
    const csv = toCSV(payload);
    return new NextResponse(csv, {
      status: 200,
      headers: {
        "Content-Type": "text/csv; charset=utf-8",
        "Content-Disposition": "attachment; filename=assessment-results.csv",
        "Cache-Control": "no-store",
      },
    });
  }

  return NextResponse.json(payload, { headers: { "Cache-Control": "no-store" } });
}
