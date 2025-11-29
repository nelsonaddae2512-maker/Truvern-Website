# Phase70-BoardHarden.ps1 — secure/public Board API, deploy, verify
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Host $t -ForegroundColor Yellow }

# 1) Locate App Router dir
Sec "Locating App Router directory"
$appCandidates = @("app","apps\tprm\app","apps\website\app") | Where-Object { Test-Path $_ }
if(-not $appCandidates){ throw "No App Router dir found (checked: app, apps\tprm\app, apps\website\app)." }
$appDir = $appCandidates[0]
Ok "Using app dir: $appDir"

# 2) Write/overwrite API route with optional token guard
Sec "Writing API route: /api/reports/board/route.ts"
$apiDir  = Join-Path $appDir "api\reports\board"
New-Item -ItemType Directory -Path $apiDir -Force | Out-Null
$apiFile = Join-Path $apiDir "route.ts"

$code = @'
export const dynamic = "force-dynamic";

import { NextResponse } from "next/server";

// If set in Vercel env, API will require this token via ?key= or x-board-key header.
// If not set, the API is public (read-only demo mode).
const REQUIRED_KEY = process.env.BOARD_READ_TOKEN || "";

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

export async function GET(req: Request) {
  const url = new URL(req.url);
  const search = url.searchParams;
  const org = search.get("org") ?? "demo-2128873b";
  const format = (search.get("format") || "json").toLowerCase();

  // Optional token guard: only enforced if env var is set
  if (REQUIRED_KEY) {
    const headerKey = req.headers.get("x-board-key") || "";
    const queryKey  = search.get("key") || "";
    if (headerKey !== REQUIRED_KEY && queryKey !== REQUIRED_KEY) {
      return new Response("Unauthorized", { status: 401 });
    }
  }

  // Demo payload (replace later with Prisma aggregation)
  const data = {
    org,
    overall: 82,
    risk: "Moderate",
    message: "All vendor controls within acceptable thresholds.",
    updated: new Date().toISOString(),
  };

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

# 3) Deploy (remote build)
Sec "Deploying (remote build)"
vercel pull --environment=production --yes | Out-Host
$deployOut = & vercel deploy --prod --yes 2>&1
$exit = $LASTEXITCODE
$deployOut | Out-Host
if ($exit -ne 0) { throw "Vercel deploy failed ($exit)" }

# Extract prod URL
$prodUrl = ($deployOut | Select-String -Pattern 'https://[^ ]+\.vercel\.app').Matches.Value | Select-Object -Last 1
if (-not $prodUrl) { throw "Could not detect production URL from deploy output." }
Ok "Production URL: $prodUrl"

# 4) Verify endpoints (JSON & CSV) on prod and custom
Sec "Verifying prod + custom endpoints"
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

Ok "Phase 70 complete."
Write-Host "If you want to require a token, run:" -ForegroundColor Yellow
Write-Host "  vercel env add BOARD_READ_TOKEN production" -ForegroundColor Yellow
Write-Host "Then call: .../api/reports/board?org=demo-2128873b&key=<your-token>" -ForegroundColor Yellow
