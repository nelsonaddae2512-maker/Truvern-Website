Set-StrictMode -Version Latest
function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Warning $t }

# === Locate App Router directory ===
Sec "Locating App Router directory"
$appDir = "app"
if (-not (Test-Path $appDir)) { throw "App directory '$appDir' not found." }
Ok "Using app dir: $appDir"

# === Ensure components folder + BoardKPISection ===
Sec "Ensuring compact KPI stripe component"
$cmpDir = "components"
if (-not (Test-Path $cmpDir)) { New-Item -ItemType Directory -Path $cmpDir | Out-Null }

$kpiFile = Join-Path $cmpDir "BoardKPISection.tsx"
if (-not (Test-Path $kpiFile)) {
  $kpiTsx = @'
"use client";
import React from "react";

type ScoreRow = { id: string; score: number; title?: string };
type BoardPayload = {
  org: string;
  overall: number;
  risk?: string;
  items: ScoreRow[];
  generatedAt?: string;
};

function useBoard(org?: string) {
  const [data, setData] = React.useState<BoardPayload | null>(null);
  const [err, setErr] = React.useState<string | null>(null);
  React.useEffect(() => {
    const qs = new URLSearchParams(window.location.search);
    const orgId = org || qs.get("org") || "demo-2128873b";
    const url = `/api/reports/board?org=${encodeURIComponent(orgId)}`;
    let alive = true;
    (async () => {
      try {
        const res = await fetch(url, { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = (await res.json()) as BoardPayload;
        if (alive) setData(json);
      } catch (e: any) {
        if (alive) setErr(e?.message || "Failed");
      }
    })();
    return () => { alive = false; };
  }, [org]);
  return { data, err };
}

export default function BoardKPISection({ org }: { org?: string }) {
  const { data, err } = useBoard(org);

  const overall = Math.round(data?.overall ?? 0);
  const items = data?.items ?? [];
  const hi = items.filter(x => (x.score ?? 0) >= 80).length;
  const mid = items.filter(x => (x.score ?? 0) >= 50 && (x.score ?? 0) < 80).length;
  const low = items.filter(x => (x.score ?? 0) < 50).length;

  return (
    <div className="mb-4 rounded-lg border border-zinc-200/70 bg-white/95 px-3 py-2 shadow-sm backdrop-blur dark:border-zinc-800/70 dark:bg-zinc-900/80">
      <div className="flex flex-wrap items-center gap-x-6 gap-y-2 text-xs sm:text-sm">
        <div className="font-medium text-zinc-900 dark:text-zinc-100">KPI</div>
        {err ? (
          <div className="text-rose-600 dark:text-rose-400">Load error: {err}</div>
        ) : (
          <>
            <div className="text-zinc-700 dark:text-zinc-300">
              Overall: <span className="font-semibold">{overall}</span>
            </div>
            <div className="text-zinc-700 dark:text-zinc-300">
              High: <span className="font-semibold">{hi}</span>
            </div>
            <div className="text-zinc-700 dark:text-zinc-300">
              Medium: <span className="font-semibold">{mid}</span>
            </div>
            <div className="text-zinc-700 dark:text-zinc-300">
              Low: <span className="font-semibold">{low}</span>
            </div>
            <a
              href={`/reports/board?org=${encodeURIComponent(data?.org || "demo-2128873b")}`}
              className="ml-auto underline text-zinc-700 dark:text-zinc-300"
            >
              View board →
            </a>
          </>
        )}
      </div>
    </div>
  );
}
'@
  [System.IO.File]::WriteAllText($kpiFile, $kpiTsx, [System.Text.Encoding]::UTF8)
  Ok "Created $kpiFile"
} else {
  Ok "Found $kpiFile (skipping write)"
}

# === Patch app/vendors/[id]/page.tsx to inject KPI stripe ===
Sec "Patching /vendors/[id]/page.tsx to inject KPI stripe"

$vendorRoot = Join-Path $appDir "vendors"
$vendorPath = Join-Path $vendorRoot "[id]"

if (-not (Test-Path $vendorRoot)) {
  [System.IO.Directory]::CreateDirectory($vendorRoot) | Out-Null
  Ok "Created folder: $vendorRoot"
}
if (-not (Test-Path $vendorPath)) {
  [System.IO.Directory]::CreateDirectory($vendorPath) | Out-Null
  Ok "Created folder with brackets: $vendorPath"
}

$vendorPage = Join-Path $vendorPath "page.tsx"

if (-not (Test-Path $vendorPage)) {
  $newVendor = @'
export default function VendorPage() {
  return (
    <main className="container mx-auto max-w-5xl px-6 py-8">
      <h1 className="text-2xl font-semibold mb-4">Vendor</h1>
    </main>
  );
}
'@
  [System.IO.File]::WriteAllText($vendorPage, $newVendor, [System.Text.Encoding]::UTF8)
  Ok "Created skeleton vendor page"
}

# Use .NET to read the file (works on all PowerShell versions)
$v = [System.IO.File]::ReadAllText($vendorPage, [System.Text.Encoding]::UTF8)

if ($v -notmatch 'import\s+BoardKPISection') {
  $v = "import BoardKPISection from `"`@/components/BoardKPISection`";`r`n" + $v
  Ok "Injected import for BoardKPISection"
}

if ($v -notmatch '<BoardKPISection') {
  $pattern = '<main[^>]*>'
  if ([regex]::IsMatch($v, $pattern)) {
    $v = [regex]::Replace($v, $pattern, { param($m) $m.Value + "`r`n      <BoardKPISection />" }, 1)
    Ok "Injected <BoardKPISection /> after <main>"
  } else {
    $v = $v -replace 'return\s*\(', "return (`r`n    <BoardKPISection />`r`n"
    Ok "Injected KPI stripe near return()"
  }
}

[System.IO.File]::WriteAllText($vendorPage, $v, [System.Text.Encoding]::UTF8)
Ok "Patched $vendorPage"

# === Deploy using stable NodeDirect ===
Sec "Deploying (Phase74-NodeDirect-PlainFix)"
if (Test-Path ".\Phase74-NodeDirect-PlainFix.ps1") {
  & .\Phase74-NodeDirect-PlainFix.ps1
} else {
  Warn "Phase74-NodeDirect-PlainFix.ps1 not found. Skipping deploy."
}

Ok "Phase78 BoardKPISection Universal complete."
