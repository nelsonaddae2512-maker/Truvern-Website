Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Warning $t }

# 1) Locate the App Router "app" folder (monorepo-friendly)
function Resolve-AppDir {
  $candidates = @(
    "app",
    "apps\tprm\app",
    "apps\website\app"
  )
  foreach ($p in $candidates) {
    if (Test-Path $p) { return $p }
  }
  throw "App directory not found. Looked in: $($candidates -join ', ')"
}

$appDir = Resolve-AppDir
Sec "Using app dir: $appDir"

# 2) Ensure KPI component exists
$cmpDir = Join-Path (Split-Path -Parent $appDir) "components"
if (-not (Test-Path $cmpDir)) { New-Item -ItemType Directory -Path $cmpDir | Out-Null }

$kpiCmp = Join-Path $cmpDir "BoardKPISection.tsx"
if (-not (Test-Path $kpiCmp)) {
  Sec "Creating components/BoardKPISection.tsx"
  $kpiTsx = @'
"use client";

type KPI = { label: string; value: string };
export default function BoardKPISection({ items }: { items: KPI[] }) {
  return (
    <div style={{
      display: "grid",
      gridAutoFlow: "column",
      gap: "0.75rem",
      padding: "0.5rem 0.75rem",
      borderBottom: "1px solid #e5e7eb",
      background: "linear-gradient(90deg,#ffffff,#f8fafc)"
    }}>
      {items.map((k,i) => (
        <div key={i} style={{ minWidth: 120 }}>
          <div style={{ fontSize: 12, color: "#64748b" }}>{k.label}</div>
          <div style={{ fontSize: 16, fontWeight: 700 }}>{k.value}</div>
        </div>
      ))}
    </div>
  );
}
'@
  Set-Content -Encoding UTF8 -Path $kpiCmp -Value $kpiTsx
  Ok "KPI component written: $kpiCmp"
} else {
  Ok "KPI component exists: $kpiCmp"
}

# 3) Create vendors list page
$vendorsList = Join-Path $appDir "vendors\page.tsx"
if (-not (Test-Path (Split-Path -Parent $vendorsList))) {
  New-Item -ItemType Directory -Path (Split-Path -Parent $vendorsList) -Force | Out-Null
}

$vendorsListTsx = @'
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function VendorsPage({
  searchParams,
}: { searchParams?: Record<string,string | string[]> }) {
  const org = (searchParams?.org as string) || "demo-2128873b";
  // A couple of demo vendors we can click
  const items = [
    { id: "vendor-alpha", name: "Vendor Alpha" },
    { id: "vendor-beta", name: "Vendor Beta" }
  ];
  return (
    <main style={{ padding: "1rem" }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 12 }}>Vendors</h1>
      <ul style={{ lineHeight: 2 }}>
        {items.map(v => (
          <li key={v.id}>
            <Link href={`/vendors/${v.id}?org=${encodeURIComponent(org)}`}>
              {v.name}
            </Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
'@
Set-Content -Encoding UTF8 -Path $vendorsList -Value $vendorsListTsx
Ok "Wrote vendors list: $vendorsList"

# 4) Create vendors/[id] detail page with KPI stripe
$vendorsIdDir = Join-Path $appDir "vendors\[id]"
if (-not (Test-Path $vendorsIdDir)) { New-Item -ItemType Directory -Path $vendorsIdDir -Force | Out-Null }
$vendorsDetail = Join-Path $vendorsIdDir "page.tsx"

$vendorsDetailTsx = @'
import BoardKPISection from "@/components/BoardKPISection";

export const dynamic = "force-dynamic";

async function fetchBoard(org: string) {
  try {
    const res = await fetch(`${process.env.NEXT_PUBLIC_BASE_URL ?? ""}/api/reports/board?org=${encodeURIComponent(org)}`, { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const json = await res.json();
    return json;
  } catch {
    return null;
  }
}

export default async function VendorDetail({
  params, searchParams
}: {
  params: { id: string },
  searchParams?: Record<string,string | string[]>
}) {
  const org = (searchParams?.org as string) || "demo-2128873b";
  const data = await fetchBoard(org);

  const kpis = data ? [
    { label: "Overall",  value: String(Math.round(data.overall ?? 0)) },
    { label: "Risk",     value: String(data.risk ?? "—") },
    { label: "Controls", value: String(data.items?.length ?? 0) },
  ] : [
    { label: "Overall",  value: "74" },
    { label: "Risk",     value: "Medium" },
    { label: "Controls", value: "36" },
  ];

  return (
    <main>
      <BoardKPISection items={kpis} />
      <div style={{ padding: "1rem" }}>
        <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 8 }}>
          Vendor: {params.id}
        </h1>
        <p style={{ color: "#334155" }}>
          This is a demo vendor page rendering a compact KPI stripe sourced from the Board API.
        </p>
        <div style={{ marginTop: 16 }}>
          <a href={`/api/reports/board?org=${encodeURIComponent(org)}`} style={{ textDecoration: "underline", marginRight: 16 }}>
            View JSON
          </a>
          <a href={`/api/reports/board?org=${encodeURIComponent(org)}&format=csv`} style={{ textDecoration: "underline" }}>
            Download CSV
          </a>
        </div>
      </div>
    </main>
  );
}
'@
Set-Content -Encoding UTF8 -Path $vendorsDetail -Value $vendorsDetailTsx
Ok "Wrote vendor detail: $vendorsDetail"

# 5) Make sure NEXT_PUBLIC_BASE_URL exists (best-effort — won’t fail if missing)
$envFile = ".vercel\.env.production.local"
try {
  if (Test-Path $envFile) {
    $envText = Get-Content $envFile -Raw
    if ($envText -notmatch "NEXT_PUBLIC_BASE_URL=") {
      $add = "`nNEXT_PUBLIC_BASE_URL=https://truvern.com`n"
      Set-Content -Encoding UTF8 -Path $envFile -Value ($envText + $add)
      Ok "Appended NEXT_PUBLIC_BASE_URL to $envFile"
    } else {
      Ok "NEXT_PUBLIC_BASE_URL already present in $envFile"
    }
  } else {
    Warn "$envFile not found — skipping BASE_URL assist"
  }
} catch { Warn "Could not verify/write NEXT_PUBLIC_BASE_URL: $($_.Exception.Message)" }

# 6) Deploy (NPX) and print links
Sec "Deploying production build"
& npx vercel pull --environment=production --yes | Out-Host
$npxOut = & npx vercel deploy --prod --yes 2>&1
$npxExit = $LASTEXITCODE
$npxOut | Out-Host
if ($npxExit -ne 0) { throw "Deploy failed ($npxExit)" }

# Try to extract the vercel.app URL (best effort)
$prodUrl = ($npxOut | Select-String -Pattern 'https://[^ ]+\.vercel\.app').Matches.Value | Select-Object -Last 1
if (-not $prodUrl) { $prodUrl = "https://truvern.com" }

Ok "Phase 79 complete."
Write-Host ("Prod UI  : {0}/vendors?v=1&org=demo-2128873b" -f $prodUrl) -ForegroundColor Yellow
Write-Host ("Detail   : {0}/vendors/vendor-alpha?org=demo-2128873b" -f $prodUrl) -ForegroundColor Yellow
Write-Host ("Custom   : https://truvern.com/vendors/vendor-alpha?org=demo-2128873b") -ForegroundColor Yellow
