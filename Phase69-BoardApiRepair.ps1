Set-StrictMode -Version Latest
Write-Host "=== Phase 69: Board API Repair & Formatter Bridge ===" -ForegroundColor Cyan

# 1. Locate app directory
$appDir = "app"
if (-not (Test-Path $appDir)) {
  throw "App directory not found"
}
$apiDir = Join-Path $appDir "api\reports\board"
New-Item -ItemType Directory -Force -Path $apiDir | Out-Null
$apiFile = Join-Path $apiDir "route.ts"

# 2. Write new API route handler
$routeCode = @'
import { NextResponse } from "next/server";

const demo = {
  org: "demo-2128873b",
  overall: 82,
  risk: "Moderate",
  message: "All vendor controls within acceptable thresholds.",
  updated: new Date().toISOString(),
};

export async function GET(req: Request) {
  const { searchParams } = new URL(req.url);
  const org = searchParams.get("org") ?? "demo-2128873b";
  const fmt = (searchParams.get("format") || "json").toLowerCase();

  const data = { ...demo, org, requestedAt: new Date().toISOString() };

  if (fmt === "csv") {
    const csv = Object.entries(data)
      .map(([k, v]) => `${k},${v}`)
      .join("\\n");
    return new Response(csv, {
      headers: {
        "Content-Type": "text/csv",
        "Cache-Control": "no-store",
      },
    });
  }

  return NextResponse.json(data, { headers: { "Cache-Control": "no-store" } });
}
'@

Set-Content -Encoding UTF8 -Path $apiFile -Value $routeCode
Write-Host "✅ API file written: $apiFile" -ForegroundColor Green

# 3. Deploy
Write-Host "Deploying via Vercel..." -ForegroundColor Cyan
vercel pull --environment=production --yes | Out-Host
vercel deploy --prod --yes | Out-Host

Write-Host "`n✅ Phase 69 complete."
Write-Host "Test JSON:  https://truvern.com/api/reports/board?org=demo-2128873b" -ForegroundColor Yellow
Write-Host "Test CSV:   https://truvern.com/api/reports/board?org=demo-2128873b&format=csv" -ForegroundColor Yellow
Write-Host "Then visit: https://truvern.com/reports/board?org=demo-2128873b" -ForegroundColor Yellow
