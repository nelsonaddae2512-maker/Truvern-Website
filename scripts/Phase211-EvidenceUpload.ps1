Write-Host "=== Phase211: Evidence Upload Engine (API route) ===" -ForegroundColor Cyan

$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root

# Ensure API directory exists
$apiDir = Join-Path $root "app\api\evidence\upload"
if (!(Test-Path $apiDir)) {
    Write-Host "Creating API directory: $apiDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $apiDir -Force | Out-Null
}

$routePath = Join-Path $apiDir "route.ts"

Write-Host "Writing /api/evidence/upload route to $routePath" -ForegroundColor Cyan

$ts = @"
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

/**
 * Phase211: Evidence Upload Engine
 *
 * This endpoint accepts either:
 *  - JSON: { vendorId, fileName }
 *  - multipart/form-data: vendorId, fileName OR file (we read .name)
 *
 * For this phase, we store metadata in the Evidence table and
 * assume the actual file is handled by a storage layer that will
 * be wired in a later phase.
 */

type JsonBody = {
  vendorId?: number | string;
  fileName?: string;
};

export async function POST(req: NextRequest) {
  try {
    const contentType = req.headers.get("content-type") || "";
    let vendorId: number | null = null;
    let fileName: string | null = null;

    if (contentType.includes("application/json")) {
      const body = (await req.json()) as JsonBody;
      vendorId = Number(body.vendorId);
      fileName = typeof body.fileName === "string" ? body.fileName : null;
    } else if (contentType.includes("multipart/form-data")) {
      const form = await req.formData();
      const vendorIdRaw = form.get("vendorId");
      const fileField = form.get("file");
      const explicitFileName = form.get("fileName");

      vendorId = vendorIdRaw != null ? Number(vendorIdRaw) : null;

      if (typeof explicitFileName === "string") {
        fileName = explicitFileName;
      } else if (
        fileField &&
        typeof (fileField as File).name === "string"
      ) {
        fileName = (fileField as File).name;
      }
    } else {
      return NextResponse.json(
        { error: "Unsupported content type" },
        { status: 400 }
      );
    }

    if (!vendorId || Number.isNaN(vendorId) || !fileName) {
      return NextResponse.json(
        { error: "vendorId and fileName are required" },
        { status: 400 }
      );
    }

    const vendor = await prisma.vendor.findUnique({
      where: { id: vendorId },
    });

    if (!vendor) {
      return NextResponse.json({ error: "Vendor not found" }, { status: 404 });
    }

    // For now we only store metadata. Storage wiring (S3 / Blob) comes later.
    const evidence = await prisma.evidence.create({
      data: {
        vendorId,
        filename: fileName,
      },
    });

    return NextResponse.json(
      {
        ok: true,
        evidence,
      },
      { status: 201 }
    );
  } catch (err) {
    console.error("Error in POST /api/evidence/upload", err);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
"@

Set-Content -Path $routePath -Value $ts -Encoding utf8

Write-Host "Route file written: $routePath" -ForegroundColor Green

Write-Host "Running TypeScript / Next.js build check (npm run build)..." -ForegroundColor Cyan
npm run build

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed. Check the errors above before proceeding." -ForegroundColor Red
    exit 1
}

Write-Host "=== Phase211 COMPLETE: Evidence upload API route is in place ===" -ForegroundColor Green
