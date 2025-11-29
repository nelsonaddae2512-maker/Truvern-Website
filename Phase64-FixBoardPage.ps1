<# Phase64-FixBoardPage.ps1 — fixes blank /reports/board
   - Rewrites board page with absolute fetch + dynamic flags
   - Ensures API has dynamic flag
   - Remote build + deploy on Vercel
#>

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn2($t){ Write-Warning $t }

# Resolve app dir
function Resolve-AppDir {
  foreach ($p in @("app","apps\tprm\app","apps\website\app")) { if (Test-Path $p) { return $p } }
  throw "App directory not found."
}
$appDir = Resolve-AppDir
Ok "Using app dir: $appDir"

# 1) Patch /reports/board page: absolute fetch + force dynamic/no cache
Sec "Patching page: /reports/board/page.tsx"
$pageDir  = Join-Path $appDir "reports\board"
$pageFile = Join-Path $pageDir "page.tsx"
New-Item -ItemType Directory -Force -Path $pageDir | Out-Null

@'
// Phase64 - Board Summary Page (fixed: absolute fetch + dynamic)
import type { Metadata } from "next";
import Link from "next/link";

export const metadata: Metadata = {
  title: "Board Summary | Truvern",
  description: "Executive summary of assessments with risk tiers.",
};

// dynamic SSR, no cache
export const dynamic = "force-dynamic";
export const revalidate = 0;

type RiskTier = "Low"|"Medium"|"High";
type AssessmentRow = { id: string; overall: number; risk: RiskTier; createdAt: string; };
type BoardSummary = {
  org: string;
  asOf: string;
  totals: { assessments: number; low: number; medium: number; high: number; averageOverall: number; };
  latest: AssessmentRow[];
};

function badge(risk: RiskTier) {
  switch (risk) {
    case "Low": return "bg-green-600 text-white";
    case "High": return "bg-red-600 text-white";
    default: return "bg-yellow-500 text-black";
  }
}

// Robust base URL for server-side fetch
function getBaseUrl() {
  const envUrl =
    process.env.NEXT_PUBLIC_APP_URL
      ?? (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : undefined);
  return envUrl ?? "http://localhost:3000";
}

export default async function BoardPage({ searchParams }: { searchParams?: Record<string,string> }) {
  const org = searchParams?.org ?? "demo-2128873b";
  const limit = searchParams?.limit ?? "5";
  const qs = new URLSearchParams({ org, limit }).toString();

  const base = getBaseUrl();
  const res = await fetch(`${base}/api/reports/board?${qs}`, { cache: "no-store" });

  if (!res.ok) {
    return (
      <main className="p-6">
        <h1 className="text-2xl font-semibold">Board Summary</h1>
        <p className="text-red-700">Unable to load summary (HTTP {res.status}).</p>
      </main>
    );
  }

  const data = (await res.json()) as BoardSummary;

  return (
    <main className="max-w-6xl mx-auto p-6">
      <div className="flex items-baseline justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Board Summary</h1>
          <p className="text-sm text-gray-600">Org: <span className="font-mono">{data.org}</span></p>
          <p className="text-xs text-gray-500">As of: {new Date(data.asOf).toLocaleString()}</p>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-sm">Avg Overall: <strong>{data.totals.averageOverall}</strong></span>
          <Link href={`${base}/api/reports/board?${qs}&format=csv`} prefetch={false} className="underline text-sm">Export CSV</Link>
        </div>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6">
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Assessments</div><div className="text-2xl font-semibold">{data.totals.assessments}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Low</div><div className="text-2xl font-semibold text-green-700">{data.totals.low}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">Medium</div><div className="text-2xl font-semibold text-yellow-700">{data.totals.medium}</div></div>
        <div className="border rounded p-3"><div className="text-xs text-gray-500">High</div><div className="text-2xl font-semibold text-red-700">{data.totals.high}</div></div>
      </div>

      <div className="mt-8 border rounded overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50">
            <tr className="text-left">
              <th className="p-3">Assessment</th>
              <th className="p-3">Created</th>
              <th className="p-3">Overall</th>
              <th className="p-3">Risk</th>
            </tr>
          </thead>
          <tbody>
            {data.latest.map((r) => (
              <tr key={r.id} className="border-t">
                <td className="p-3 font-mono">{r.id}</td>
                <td className="p-3">{new Date(r.createdAt).toLocaleString()}</td>
                <td className="p-3">{r.overall}</td>
                <td className="p-3"><span className={`px-2 py-1 rounded text-xs ${badge(r.risk)}`}>{r.risk}</span></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <p className="text-xs text-gray-500 mt-4">Risk tiers: Low ≥ 85, Medium ≥ 70, else High.</p>
    </main>
  );
}
'@ | Set-Content -Encoding UTF8 $pageFile
Ok "Board page patched."

# 2) Ensure API route is dynamic (no cache)
Write-Host "`n=== Ensuring API is dynamic (optional) ===" -ForegroundColor Cyan
$apiFile = Join-Path $appDir "api\reports\board\route.ts"
if (Test-Path $apiFile) {
  $api = Get-Content $apiFile -Raw
  if ($api -notmatch 'export const dynamic = "force-dynamic"') {
    $insert = 'export const dynamic = "force-dynamic";'
    $api = "$insert`r`n$api"
    Set-Content -Encoding UTF8 -Path $apiFile -Value $api
    Write-Host "Injected dynamic flag into API route." -ForegroundColor Green
  } else {
    Write-Host "API already dynamic." -ForegroundColor Yellow
  }
} else {
  Write-Host "API file not found; skipping." -ForegroundColor Red
}

# 3) Deploy
Sec "Deploying (remote build)"
vercel pull --environment=production --yes | Out-Host
iex "vercel deploy --prod --yes"
if ($LASTEXITCODE -ne 0) { throw "Vercel deploy failed ($LASTEXITCODE)" }
Ok "Fix deployed."
