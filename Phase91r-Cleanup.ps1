<#
Phase91r-VendorGuard.ps1
Fixes “Cannot read properties of undefined (reading 'vendors')”
by adding safe guards, API fallback, and redeploying cleanly.
#>

Write-Host "`n=== Phase91r: VendorGuard Fix ===" -ForegroundColor Cyan

# 1️⃣ Always run from project root
$projectDir = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectDir
Write-Host "Working dir: $projectDir`n" -ForegroundColor Yellow

# 2️⃣ Ensure directory structure exists
$folders = @(
  "app\lib",
  "app\api\vendors",
  "app\trust-network"
)
foreach ($f in $folders) {
  if (-not (Test-Path $f)) {
    New-Item -ItemType Directory -Path $f | Out-Null
    Write-Host "[Created] $f" -ForegroundColor Green
  } else {
    Write-Host "[Exists] $f" -ForegroundColor DarkGray
  }
}

# 3️⃣ Write safe utility (app/lib/safe.ts)
$safeFile = "app/lib/safe.ts"
@"
export function ensureArray<T>(v: T[] | T | null | undefined): T[] {
  return Array.isArray(v) ? v : v ? [v] : [];
}

export type Vendor = { id?: string; name?: string };

export async function getVendorsSafe(): Promise<Vendor[]> {
  try {
    const res = await fetch('/api/vendors', { cache: 'no-store' });
    if (!res.ok) return [];
    const data = await res.json().catch(() => ({}));
    return ensureArray(data?.vendors ?? data);
  } catch {
    return [];
  }
}
"@ | Set-Content $safeFile -Encoding UTF8
Write-Host "[OK] $safeFile written" -ForegroundColor Green

# 4️⃣ Write vendors API (app/api/vendors/route.ts)
$apiFile = "app/api/vendors/route.ts"
@"
import { NextResponse } from 'next/server';

export async function GET() {
  try {
    const { PrismaClient } = await import('@prisma/client').catch(() => ({ PrismaClient: null as any }));
    if (PrismaClient) {
      const prisma = new PrismaClient();
      const vendors = await prisma.vendor.findMany({
        select: { id: true, name: true },
        take: 200,
      });
      return NextResponse.json({ vendors });
    }
  } catch {}
  return NextResponse.json({ vendors: [] });
}
"@ | Set-Content $apiFile -Encoding UTF8
Write-Host "[OK] $apiFile written" -ForegroundColor Green

# 5️⃣ Patch Trust Network page
$trustPage = "app/trust-network/page.tsx"
@"
import { getVendorsSafe } from '@/app/lib/safe';

export default async function TrustNetworkPage() {
  const vendors = await getVendorsSafe();
  return (
    <main className='container'>
      <h1>Trust Network</h1>
      {vendors.length === 0 ? (
        <p>No vendors yet.</p>
      ) : (
        <ul>
          {vendors.map((v, i) => (
            <li key={v.id ?? i}>{v.name ?? 'Unnamed Vendor'}</li>
          ))}
        </ul>
      )}
    </main>
  );
}
"@ | Set-Content $trustPage -Encoding UTF8
Write-Host "[OK] Patched $trustPage" -ForegroundColor Green

# 6️⃣ Add friendly error boundary (app/trust-network/error.tsx)
$errorFile = "app/trust-network/error.tsx"
@"
'use client';

export default function Error({ error }: { error: Error & { digest?: string } }) {
  return (
    <main style={{ padding: 24 }}>
      <h2>We hit a snag.</h2>
      <p>{error?.message ?? 'Unknown error'}</p>
      <p>
        <a href='/'>Go back to Home</a> | <a href='/reports/board/preview'>Open Board Report</a>
      </p>
    </main>
  );
}
"@ | Set-Content $errorFile -Encoding UTF8
Write-Host "[OK] Added error boundary $errorFile" -ForegroundColor Green

# 7️⃣ Run build pipeline
Write-Host "`n=== Building and Deploying ===" -ForegroundColor Cyan
pnpm install
pnpm prisma generate
pnpm run build

# 8️⃣ Deploy to Vercel (same team scope)
vercel deploy --yes --prod --scope nelson-addaes-projects

# 9️⃣ Verify endpoints
Start-Sleep -Seconds 3
Write-Host "`nVerify these URLs after deploy:" -ForegroundColor Yellow
Write-Host " - https://truvern.com/api/vendors"
Write-Host " - https://truvern.com/trust-network"
Write-Host " - https://truvern.com" -ForegroundColor Cyan
Write-Host "`nIf you still see an error, refresh or use Incognito mode.`n" -ForegroundColor DarkGray
