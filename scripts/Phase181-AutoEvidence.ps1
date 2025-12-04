# =========================================
# Phase181-AutoEvidence: Panel & List API
# Auto-detects vendor [param] page.tsx
# =========================================

Write-Host "===== Phase181-AutoEvidence START =====" -ForegroundColor Cyan

$root = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $root

# 1) Auto-detect vendor param folder (e.g. [id])
$vendorsDir = Join-Path $root "app\vendors"

if (-not (Test-Path $vendorsDir)) {
    Write-Host "ERROR: app\\vendors directory not found at $vendorsDir" -ForegroundColor Red
    exit 1
}

$paramFolder = Get-ChildItem $vendorsDir -Directory | Where-Object { $_.Name -like "*[*]*" } | Select-Object -First 1

if (-not $paramFolder) {
    Write-Host "ERROR: No [param] folder found under app\\vendors" -ForegroundColor Red
    Write-Host "Expected something like app\\vendors\\[id]\\page.tsx" -ForegroundColor Yellow
    exit 1
}

$vendorParamName = $paramFolder.Name
$vendorPage = Join-Path $paramFolder.FullName "page.tsx"

Write-Host "Detected vendor param folder: $vendorParamName" -ForegroundColor Green
Write-Host "Expected vendor page file:   $vendorPage" -ForegroundColor Green

if (-not (Test-Path $vendorPage)) {
    Write-Host "ERROR: vendor page.tsx NOT found at $vendorPage" -ForegroundColor Red
    exit 1
}

# 2) Ensure evidence list API directory exists
$evidenceApiDir = Join-Path $root "app\api\evidence\list"
if (-not (Test-Path $evidenceApiDir)) {
    New-Item -ItemType Directory -Path $evidenceApiDir | Out-Null
    Write-Host "Created evidence list API directory: $evidenceApiDir" -ForegroundColor Green
} else {
    Write-Host "Evidence list API directory already exists." -ForegroundColor DarkGray
}

# 3) Write /api/evidence/list route.ts
$apiRoutePath = Join-Path $evidenceApiDir "route.ts"
$apiRouteCode = @'
import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url);
    const vendorIdParam = searchParams.get('vendorId');
    const vendorId = vendorIdParam ? Number(vendorIdParam) : NaN;

    if (!vendorId || !Number.isInteger(vendorId)) {
      return NextResponse.json(
        { error: 'vendorId is required and must be an integer' },
        { status: 400 }
      );
    }

    const evidence = await prisma.evidence.findMany({
      where: { vendorId },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json({ ok: true, evidence });
  } catch (err) {
    console.error('Failed to load evidence list', err);
    return NextResponse.json(
      { error: 'Failed to load evidence list' },
      { status: 500 }
    );
  }
}
'@

Set-Content -Path $apiRoutePath -Value $apiRouteCode -Encoding UTF8
Write-Host "Wrote /api/evidence/list route.ts" -ForegroundColor Green

# 4) Create components/EvidenceList.tsx
$componentsDir = Join-Path $root "components"
if (-not (Test-Path $componentsDir)) {
    New-Item -ItemType Directory -Path $componentsDir | Out-Null
    Write-Host "Created components directory." -ForegroundColor Green
}

$evidenceListPath = Join-Path $componentsDir "EvidenceList.tsx"
$evidenceListCode = @"
'use client';

import { useEffect, useState } from 'react';

type EvidenceItem = {
  id: number;
  title: string | null;
  description: string | null;
  fileUrl: string | null;
  createdAt?: string;
};

export default function EvidenceList({ vendorId }: { vendorId: number }) {
  const [items, setItems] = useState<EvidenceItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/evidence/list?vendorId=' + vendorId)
      .then((res) => res.json())
      .then((data) => {
        setItems(data.evidence || []);
        setLoading(false);
      })
      .catch(() => {
        setItems([]);
        setLoading(false);
      });
  }, [vendorId]);

  if (loading) {
    return <p className="text-sm text-slate-400">Loading evidence…</p>;
  }

  if (!items.length) {
    return <p className="text-sm text-slate-400">No evidence uploaded yet.</p>;
  }

  return (
    <div className="space-y-3">
      {items.map((ev) => (
        <div
          key={ev.id}
          className="rounded-lg border border-slate-800 bg-slate-950/60 p-3"
        >
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-sm font-semibold text-slate-100">
                {ev.title || 'Untitled evidence'}
              </p>
              <p className="text-xs text-slate-400">
                {ev.description || '–'}
              </p>
            </div>
            {ev.fileUrl ? (
              <a
                href={ev.fileUrl}
                target="_blank"
                rel="noopener noreferrer"
                className="text-xs font-medium text-emerald-400 hover:underline"
              >
                Download
              </a>
            ) : (
              <span className="text-xs text-slate-500">No file</span>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
"@

Set-Content -Path $evidenceListPath -Value $evidenceListCode -Encoding UTF8
Write-Host "Wrote components/EvidenceList.tsx" -ForegroundColor Green

# 5) Patch vendor [param] page.tsx: add import & panel
$vendorSource = Get-Content $vendorPage -Raw

# 5a) Import
if ($vendorSource -notmatch "EvidenceList from '@/components/EvidenceList'") {
    $importLine = "import EvidenceList from '@/components/EvidenceList';`n"
    $vendorSource = $importLine + $vendorSource
    Write-Host "Added EvidenceList import to vendor page." -ForegroundColor Green
} else {
    Write-Host "EvidenceList import already present." -ForegroundColor DarkGray
}

# 5b) Panel markup
$panelMarkup = @"
{/* Evidence Panel */}
<div className="mt-8 rounded-xl border border-slate-800 bg-slate-950/70 p-4">
  <h2 className="text-lg font-semibold text-slate-100 mb-3">
    Evidence &amp; Artifacts
  </h2>
  <EvidenceList vendorId={vendor.id} />
</div>
"@

if ($vendorSource -notmatch "<EvidenceList vendorId=") {
    $vendorSource = $vendorSource + "`n`n" + $panelMarkup
    Write-Host "Appended Evidence panel to vendor page." -ForegroundColor Green
} else {
    Write-Host "Vendor page already references EvidenceList." -ForegroundColor DarkGray
}

Set-Content -Path $vendorPage -Value $vendorSource -Encoding UTF8

# 6) Git add / commit / push
git add app/api/evidence/list
git add components/EvidenceList.tsx
git add "app/vendors/$vendorParamName/page.tsx"

$status = git status --short
Write-Host "Git status:" -ForegroundColor Yellow
Write-Host $status

if (-not [string]::IsNullOrWhiteSpace($status)) {
    git commit -m "Phase181-AutoEvidence: Evidence panel & list API" | Out-Null
    git push | Out-Null
    Write-Host "Changes committed and pushed." -ForegroundColor Green
} else {
    Write-Host "No changes to commit." -ForegroundColor DarkGray
}

Write-Host "===== Phase181-AutoEvidence COMPLETE =====" -ForegroundColor Cyan
