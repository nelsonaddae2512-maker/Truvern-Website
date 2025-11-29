export const dynamic = "force-dynamic";
export const runtime = "nodejs"; // Prisma needs Node runtime (not edge)

import { NextResponse } from "next/server";

let PrismaClient: any;
try { ({ PrismaClient } = require("@prisma/client")); } catch { /* no prisma available */ }

const REQUIRED_KEY = process.env.BOARD_READ_TOKEN || "";

type Board = {
  org: string;
  overall: number | string;
  risk: string;
  message?: string;
  updated: string;
};

function ok(data: any) {
  return NextResponse.json(data, { headers: { "Cache-Control": "no-store" } });
}
function csv(body: string) {
  return new Response(body, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Cache-Control": "no-store",
      "Content-Disposition": "attachment; filename=board-summary.csv"
    }
  });
}

function demo(org: string): Board {
  return {
    org,
    overall: 82,
    risk: "Moderate",
    message: "Demo payload (Prisma unavailable or no data).",
    updated: new Date().toISOString(),
  };
}

// Best-effort fetch from Prisma with many fallbacks (schema-agnostic-ish)
async function fetchBoardFromPrisma(org: string): Promise<Board | null> {
  if (!PrismaClient) return null;
  const prisma = new PrismaClient();

  try {
    // Try common patterns:
    // 1) Organization by slug
    const bySlug = await prisma.organization?.findFirst?.({
      where: { OR: [{ slug: org }, { id: org }] },
      select: { id: true, slug: true, name: true }
    });

    const orgId = bySlug?.id ?? org;

    // 2) Latest assessment/result row for that org
    // Try table names commonly used; if missing, each will fail harmlessly.
    let latest: any = null;

    // assessments (with score, risk)
    try {
      latest = await prisma.assessment?.findFirst?.({
        where: { OR: [{ orgId }, { organizationId: orgId }] },
        orderBy: [{ updatedAt: "desc" }],
        select: { overall: true, score: true, risk: true, result: true, updatedAt: true }
      });
    } catch {}

    // assessmentResult(s)
    if (!latest) {
      try {
        latest = await prisma.assessmentResult?.findFirst?.({
          where: { OR: [{ orgId }, { organizationId: orgId }] },
          orderBy: [{ updatedAt: "desc" }],
          select: { overall: true, score: true, risk: true, updatedAt: true }
        });
      } catch {}
    }

    // vendor/summary or similar
    if (!latest) {
      try {
        latest = await prisma.summary?.findFirst?.({
          where: { OR: [{ orgId }, { organizationId: orgId }] },
          orderBy: [{ updatedAt: "desc" }],
          select: { overall: true, risk: true, updatedAt: true }
        });
      } catch {}
    }

    if (!latest) return null;

    const overall =
      typeof latest.overall !== "undefined" ? latest.overall :
      typeof latest.score   !== "undefined" ? latest.score   : "N/A";

    const risk =
      latest.risk ??
      (typeof overall === "number"
        ? (overall >= 85 ? "Low" : overall >= 70 ? "Moderate" : "High")
        : "Unknown");

    return {
      org: bySlug?.slug ?? org,
      overall,
      risk,
      message: "Live board summary from Prisma.",
      updated: (latest.updatedAt ?? new Date()).toISOString?.() ?? new Date().toISOString(),
    };
  } catch {
    return null;
  } finally {
    try { await prisma.$disconnect?.(); } catch {}
  }
}

export async function GET(req: Request) {
  const url = new URL(req.url);
  const search = url.searchParams;
  const org = search.get("org") ?? "demo-2128873b";
  const format = (search.get("format") || "json").toLowerCase();

  // Optional token guard (only enforced if env var exists)
  if (REQUIRED_KEY) {
    const headerKey = req.headers.get("x-board-key") || "";
    const queryKey  = search.get("key") || "";
    if (headerKey !== REQUIRED_KEY && queryKey !== REQUIRED_KEY) {
      return new Response("Unauthorized", { status: 401 });
    }
  }

  // Try Prisma; fallback to demo if unavailable/no data
  const data = (await fetchBoardFromPrisma(org)) ?? demo(org);

  if (format === "csv") {
    const csvBody =
      Object.keys(data).join(",") + "\n" +
      Object.values(data).join(",");
    return csv(csvBody);
  }

  return ok(data);
}
