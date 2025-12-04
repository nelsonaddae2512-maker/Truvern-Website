# ==============================================
# Phase185 - Evidence List Live (Prisma-backed)
# ==============================================

param()

$projectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$logDir      = "$projectRoot\scripts\logs"
$timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile     = "$logDir\phase185-evidence-list-live-$timestamp.log"

if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

function Write-Log {
    param(
        [string]$Message,
        [string]$Color = "Cyan"
    )
    Write-Host $Message -ForegroundColor $Color
    Add-Content -Path $logFile -Value ("[{0}] {1}" -f (Get-Date), $Message)
}

Write-Log "===== Phase185: Evidence List Live START =====" "Yellow"

# ------------------------------------------------------------------
# Ensure correct working directory (never run from system32)
# ------------------------------------------------------------------
if ((Get-Location).Path -ne $projectRoot) {
    Write-Log "Switching to project root: $projectRoot" "Green"
    Set-Location $projectRoot
}

Write-Log "Current Directory: $(Get-Location)" "Green"

# ------------------------------------------------------------------
# Ensure evidence list API directory exists
# ------------------------------------------------------------------
$evidenceApiDir = Join-Path $projectRoot "app\api\evidence\list"
$routeFile      = Join-Path $evidenceApiDir "route.ts"

if (-not (Test-Path $evidenceApiDir)) {
    Write-Log "Creating evidence list API directory: $evidenceApiDir" "Yellow"
    New-Item -Path $evidenceApiDir -ItemType Directory -Force | Out-Null
}

# ------------------------------------------------------------------
# Write Prisma-backed evidence list route.ts
# ------------------------------------------------------------------
Write-Log "Writing Prisma-backed evidence list route: $routeFile" "Yellow"

@'
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);

    const vendorIdParam = searchParams.get("vendorId");
    const takeParam = searchParams.get("take");
    const cursorParam = searchParams.get("cursor");

    const where: { vendorId?: number } = {};

    if (vendorIdParam) {
      const vendorId = Number(vendorIdParam);
      if (!Number.isNaN(vendorId)) {
        where.vendorId = vendorId;
      }
    }

    const take = takeParam ? Math.min(parseInt(takeParam, 10) || 20, 100) : 20;
    const cursor = cursorParam ? { id: Number(cursorParam) } : undefined;

    const queryOptions: any = {
      where,
      orderBy: { createdAt: "desc" },
      take: take + 1,
      include: {
        vendor: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    };

    if (cursor) {
      queryOptions.cursor = cursor;
      queryOptions.skip = 1;
    }

    const records = await prisma.evidence.findMany(queryOptions);

    const hasMore = records.length > take;
    const items = hasMore ? records.slice(0, take) : records;

    const evidence = items.map((e: any) => ({
      id: e.id,
      vendorId: e.vendorId,
      vendorName: e.vendor?.name ?? null,
      title: e.title ?? e.name ?? "",
      description: e.description ?? null,
      fileUrl: e.fileUrl ?? null,
      createdAt: e.createdAt,
    }));

    const nextCursor = hasMore ? items[items.length - 1].id : null;

    return NextResponse.json(
      {
        ok: true,
        count: evidence.length,
        evidence,
        nextCursor,
      },
      {
        status: 200,
      }
    );
  } catch (error) {
    console.error("Evidence list API error", error);
    return NextResponse.json(
      {
        ok: false,
        error: "Failed to load evidence list",
      },
      {
        status: 200,
      }
    );
  }
}
'@ | Set-Content -Path $routeFile -Encoding UTF8

Write-Log "route.ts written." "Green"

# ------------------------------------------------------------------
# Git add / commit / push
# ------------------------------------------------------------------
Write-Log "Running git status..." "Yellow"
git status | Out-String | Add-Content -Path $logFile

Write-Log "Staging evidence list route + Phase185 script..." "Yellow"
git add "app/api/evidence/list/route.ts" "scripts/Phase185-EvidenceListLive.ps1"

Write-Log "Creating commit..." "Yellow"
git commit -m "Phase185: wire /api/evidence/list to Prisma" | Tee-Object -FilePath $logFile -Append

Write-Log "Pushing to origin/main..." "Yellow"
git push | Tee-Object -FilePath $logFile -Append

# ------------------------------------------------------------------
# Re-run Phase180 health check
# ------------------------------------------------------------------
$healthScript = Join-Path $projectRoot "scripts\Phase180-RouteHealthCheck.ps1"
if (Test-Path $healthScript) {
    Write-Log "Running Phase180 route health check..." "Yellow"
    & $healthScript
} else {
    Write-Log "Phase180 health script not found at $healthScript - skipping health check." "Red"
}

Write-Log "===== Phase185: Evidence List Live COMPLETE =====" "Yellow"
