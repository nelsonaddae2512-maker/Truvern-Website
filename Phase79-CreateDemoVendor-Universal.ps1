Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Warning $t }

# === Locate App Router directory ===
function Resolve-AppDir {
  $candidates = @("app","apps\tprm\app","apps\website\app")
  foreach ($p in $candidates) {
    if (Test-Path $p) { return (Resolve-Path $p).Path }
  }
  throw "App directory not found. Looked in: $($candidates -join ', ')"
}

$appDir = Resolve-AppDir
Sec "Using app dir: $appDir"

# === Safely resolve components directory ===
$rootDir = Split-Path -Parent $appDir
if ([string]::IsNullOrWhiteSpace($rootDir)) { $rootDir = Get-Location }
$cmpDir = Join-Path $rootDir "components"

if (-not (Test-Path $cmpDir)) {
  New-Item -ItemType Directory -Path $cmpDir -Force | Out-Null
  Ok "Created components directory: $cmpDir"
} else {
  Ok "Components directory found: $cmpDir"
}

# === Ensure KPI component exists ===
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
  [System.IO.File]::WriteAllText($kpiCmp, $kpiTsx, [System.Text.Encoding]::UTF8)
  Ok "KPI component written: $kpiCmp"
} else {
  Ok "KPI component exists: $kpiCmp"
}

# === Create vendor pages ===
$vendorsList = Join-Path $appDir "vendors\page.tsx"
New-Item -ItemType Directory -Path (Split-Path -Parent $vendorsList) -Force | Out-Null

$vendorsListTsx = @'
import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function VendorsPage({
  searchParams,
}: { searchParams?: Record<string,string | string[]> }) {
  const org = (searchParams?.org as string) || "demo-2128873b";
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
            <Link href={`/vendors/${v.id}?org=${encodeURIComponent(org)}`}>{v.name}</Link>
          </li>
        ))}
      </ul>
    </main>
  );
}
'@
[System.IO.File]::WriteAllText($vendorsList, $vendorsListTsx, [System.Text.Encoding]::UTF8)
Ok "Wrote vendors list: $vendorsList"

$vendorsIdDir = Join-Path $appDir "vendors\[id]"
New-Item -ItemType Directory -Path $vendorsIdDir -Force | Out-Null
$vendorsDetail = Join-Path $vendorsIdDir "page.tsx"

$vendorsDetailTsx = @'
import BoardKPISection from "@/components/BoardKPISection";

export const dynamic = "force-dynamic";

export default async function VendorDetail({
  params, searchParams
}: {
  params: { id: string },
  searchParams?: Record<string,string | string[]>
}) {
  const org = (searchParams?.org as string) || "demo-2128873b";
  const kpis = [
    { label: "Overall", value: "84" },
    { label: "Risk", value: "Low" },
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
          Demo vendor detail with embedded KPI stripe.
        </p>
      </div>
    </main>
  );
}
'@
[System.IO.File]::WriteAllText($vendorsDetail, $vendorsDetailTsx, [System.Text.Encoding]::UTF8)
Ok "Wrote vendor detail: $vendorsDetail"

# === Deploy via NPX ===
Sec "Deploying production build"
& npx vercel pull --environment=production --yes | Out-Host
$npxOut = & npx vercel deploy --prod --yes 2>&1
$npxExit = $LASTEXITCODE
$npxOut | Out-Host
if ($npxExit -ne 0) { throw "Deploy failed ($npxExit)" }

$prodUrl = ($npxOut | Select-String -Pattern 'https://[^ ]+\.vercel\.app').Matches.Value | Select-Object -Last 1
if (-not $prodUrl) { $prodUrl = "https://truvern.com" }

Ok "Phase79 CreateDemoVendor-Universal complete."

Write-Host ("Prod UI  : {0}/vendors?v=1`"&`"org=demo-2128873b" -f $prodUrl) -ForegroundColor Yellow
Write-Host ("Detail   : {0}/vendors/vendor-alpha`"?org=demo-2128873b" -f $prodUrl) -ForegroundColor Yellow
Write-Host ("Custom   : https://truvern.com/vendors/vendor-alpha`"?org=demo-2128873b") -ForegroundColor Yellow
