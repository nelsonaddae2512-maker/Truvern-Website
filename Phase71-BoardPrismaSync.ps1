# Phase71-BoardPrismaSync.ps1 — Board API reads Prisma, keeps CSV/JSON + optional token, deploys with npx vercel
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Host $t -ForegroundColor Yellow }

# 1) Locate App Router
Sec "Locating App Router directory"
$appCandidates = @("app","apps\tprm\app","apps\website\app") | Where-Object { Test-Path $_ }
if(-not $appCandidates){ throw "No App Router dir found (checked: app, apps\tprm\app, apps\website\app)." }
$appDir = $appCandidates[0]
Ok "Using app dir: $appDir"

# 2) Write Prisma-backed API route (safe fallbacks)
Sec "Writing API route: /api/reports/board/route.ts"
$apiDir  = Join-Path $appDir "api\reports\board"
New-Item -ItemType Directory -Path $apiDir -Force | Out-Null
$apiFile = Join-Path $apiDir "route.ts"

$code = @'
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
'@

Set-Content -Encoding UTF8 -Path $apiFile -Value $code
Ok "API file written: $apiFile"

# 3) Deploy with NPX Vercel (avoids old PS alias)
Sec "Deploying (remote build)"
npx vercel pull --environment=production --yes | Out-Host
$npxOut = & npx vercel deploy --prod --yes 2>&1
$codeExit = $LASTEXITCODE
$npxOut | Out-Host
if ($codeExit -ne 0) { throw "Vercel deploy failed ($codeExit)" }

# Extract prod URL
$prodUrl = ($npxOut | Select-String -Pattern 'https://[^ ]+\.vercel\.app').Matches.Value | Select-Object -Last 1
if (-not $prodUrl) { throw "Could not detect production URL from deploy output." }
Ok "Production URL: $prodUrl"

# 4) Verify prod + custom (JSON, CSV, UI)
Sec "Verifying endpoints"
$urls = @(
  "$prodUrl/api/reports/board?org=demo-2128873b",
  "$prodUrl/api/reports/board?org=demo-2128873b&format=csv",
  "https://truvern.com/api/reports/board?org=demo-2128873b",
  "https://truvern.com/api/reports/board?org=demo-2128873b&format=csv",
  "$prodUrl/reports/board?org=demo-2128873b",
  "https://truvern.com/reports/board?org=demo-2128873b"
)

foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -Method GET -TimeoutSec 25 -Headers @{ "Cache-Control"="no-cache" } -ErrorAction Stop
    Write-Host ("{0} -> {1}" -f $u, [int]$r.StatusCode) -ForegroundColor Green
  } catch {
    Write-Host ("{0} -> FAILED ({1})" -f $u, $_.Exception.Message) -ForegroundColor Yellow
  }
}

Ok "Phase 71 complete."
Write-Host "Optional: require token -> vercel env add BOARD_READ_TOKEN production" -ForegroundColor Yellow
Write-Host "Then call: .../api/reports/board?org=demo-2128873b&key=<token>" -ForegroundColor Yellow
