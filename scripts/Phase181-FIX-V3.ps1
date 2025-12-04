# ================================
# Phase181-FIX-V3: Evidence Panel & List API
# ================================
Write-Host "===== Phase181-FIX-V3: Evidence Panel & List API START =====" -ForegroundColor Cyan

$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root

# Correct vendor detail file (your actual file)
$vendorPage = "$root\app\vendors\[id]page.tsx"

# Evidence API /list
$evidenceApiDir = "$root\app\api\evidence\list"

# --- Verify vendor file exists ---
if (-Not (Test-Path $vendorPage)) {
    Write-Host "ERROR: Vendor file not found at: $vendorPage" -ForegroundColor Red
    exit
} else {
    Write-Host "Vendor file FOUND at: $vendorPage" -ForegroundColor Green
}

# --- Ensure evidence list API directory exists ---
if (-Not (Test-Path $evidenceApiDir)) {
    New-Item -ItemType Directory -Path $evidenceApiDir | Out-Null
    Write-Host "Created evidence list API directory." -ForegroundColor Green
} else {
    Write-Host "Evidence list API directory already exists."
}

# --- Write API route ---
$apiRoute = @"
import { NextResponse } from 'next/server';
import prisma from '@/lib/prisma';

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const vendorId = Number(searchParams.get('vendorId'));

    if (!vendorId) {
      return NextResponse.json({ error: 'vendorId is required' }, { status: 400 });
    }

    const evidence = await prisma.evidence.findMany({
      where: { vendorId },
      orderBy: { createdAt: 'desc' }
    });

    return NextResponse.json({ ok: true, evidence });
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: 'Failed to load evidence' }, { status: 500 });
  }
}
"@

Set-Content "$evidenceApiDir\route.ts" $apiRoute -Encoding UTF8
Write-Host "Created /api/evidence/list route." -ForegroundColor Green

# --- Create EvidenceList component ---
$componentDir = "$root\components"
if (-Not (Test-Path $componentDir)) { New-Item -ItemType Directory $componentDir | Out-Null }

$componentFile = "$componentDir\EvidenceList.tsx"
$componentContent = @"
'use client';

import { useEffect, useState } from 'react';

export default function EvidenceList({ vendorId }: { vendorId: number }) {
  const [items, setItems] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/evidence/list?vendorId=' + vendorId)
      .then(r => r.json())
      .then(d => {
        setItems(d.evidence || []);
        setLoading(false);
      });
  }, [vendorId]);

  if (loading) return <p>Loading evidence...</p>;

  return (
    <div className='space-y-3'>
      {items.map((ev) => (
        <div key={ev.id} className='p-3 rounded-lg border border-slate-700 bg-slate-900/40'>
          <p className='font-semibold'>{ev.title}</p>
          <p className='text-sm text-slate-300'>{ev.description}</p>

          {ev.fileUrl ? (
            <a href={ev.fileUrl} target='_blank' className='text-emerald-400 underline mt-2 inline-block'>
              Download
            </a>
          ) : (
            <p className='text-red-400 text-sm mt-2'>No file available</p>
          )}
        </div>
      ))}
    </div>
  );
}
"@

Set-Content $componentFile $componentContent -Encoding UTF8
Write-Host "Created EvidenceList component." -ForegroundColor Green

# --- Patch vendor detail page ---
$vendorRaw = Get-Content $vendorPage -Raw

$panelMarkup = @"
{/* Evidence Panel */}
<div className='mt-8 p-4 rounded-xl bg-slate-900/40 border border-slate-800'>
  <h2 className='text-xl font-bold mb-3'>Evidence</h2>
  <EvidenceList vendorId={vendor.id} />
</div>
"@

if ($vendorRaw -notmatch "EvidenceList") {
    $patched = $vendorRaw + "`n`n" + $panelMarkup
    Set-Content $vendorPage $patched -Encoding UTF8
    Write-Host "Vendor detail page patched with evidence panel." -ForegroundColor Green
} else {
    Write-Host "Vendor detail page already contains evidence panel."
}

# --- Git operations ---
git add app/api/evidence/list
git add app/vendors/[id]page.tsx
git add components/EvidenceList.tsx

git commit -m "Phase181-FIX-V3: Evidence panel & list API for [id]page.tsx"
git push

Write-Host "===== Phase181-FIX-V3 COMPLETE =====" -ForegroundColor Cyan
