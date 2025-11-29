# Phase68-BoardFinalize.ps1 — write Board page, deploy, verify, alias if needed
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function OK($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Host $t -ForegroundColor Yellow }

# 1) Find App Router dir
Sec "Locating App Router directory"
$appCandidates = @("app","apps\tprm\app","apps\website\app") | Where-Object { Test-Path $_ }
if(-not $appCandidates){ throw "No App Router dir found (checked: app, apps\tprm\app, apps\website\app)." }
$appDir = $appCandidates[0]
OK ("Using app dir: {0}" -f $appDir)

# Stop re-creating the page since it's already written
return

# 2) Write /reports/board/page.tsx (client fetch; no caching issues)
Sec "Writing page: /reports/board/page.tsx"
$boardDir = Join-Path $appDir "reports\board"
New-Item -ItemType Directory -Path $boardDir -Force | Out-Null
$pageFile = Join-Path $boardDir "page.tsx"

$pageTsx = @"
"use client";

import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";

type BoardData = { overall?: string | number; risk?: string; message?: string };

export default function BoardSummaryPage() {
  const params = useSearchParams();
  const org = params.get("org") ?? "demo-2128873b";

  const apiUrl = useMemo(() => {
    const base = process.env.NEXT_PUBLIC_BASE_URL || "";
    const q = new URLSearchParams({ org });
    return `${base}/api/reports/board?${q.toString()}`;
  }, [org]);

  const [data, setData] = useState<BoardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        setLoading(true); setErr(null);
        const res = await fetch(apiUrl, { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        if (alive) setData(json);
      } catch (e:any) {
        if (alive) setErr(e?.message ?? "Failed to load");
      } finally {
        if (alive) setLoading(false);
      }
    })();
    return () => { alive = false; };
  }, [apiUrl]);

  return (
    <main style={{ fontFamily: "system-ui, Segoe UI, Roboto, Arial", padding: "2rem", maxWidth: 960, margin: "0 auto" }}>
      <h1 style={{ marginBottom: "0.5rem" }}>📊 Board Summary</h1>
      <p style={{ color: "#6b7280", marginBottom: "1.25rem" }}>
        Organization: <strong>{org}</strong>
      </p>

      <section style={{ background: "#f9fafb", padding: "1rem", borderRadius: 8, boxShadow: "0 1px 2px rgba(0,0,0,0.06)" }}>
        {loading && <p>Loading latest board summary…</p>}
        {err && <p style={{ color: "#b91c1c" }}>Error: {err}</p>}
        {!loading && !err && (
          <div>
            <div style={{ display: "grid", gridTemplateColumns: "200px 1fr", rowGap: "0.5rem" }}>
              <div style={{ color: "#6b7280" }}>Overall Score</div>
              <div><strong>{data?.overall ?? "N/A"}</strong></div>
              <div style={{ color: "#6b7280" }}>Risk Tier</div>
              <div><strong>{data?.risk ?? "Unknown"}</strong></div>
            </div>

            <p style={{ marginTop: "1rem", color: "#6b7280" }}>
              Source: <code>/api/reports/board</code> (runtime, no caching).
            </p>

            <div style={{ marginTop: "0.75rem" }}>
              <a href={`/api/reports/board?org=${encodeURIComponent(org)}`} style={{ marginRight: "1rem", textDecoration: "underline" }}>
                View JSON
              </a>
              <a href={`/api/reports/board?org=${encodeURIComponent(org)}&format=csv`} style={{ textDecoration: "underline" }}>
                Download CSV
              </a>
            </div>
          </div>
        )}
      </section>

      <footer style={{ marginTop: "2rem", color: "#6b7280", fontSize: 14 }}>
        © Truvern • Phase 68 Board Summary
      </footer>
    </main>
  );
}
"@
Set-Content -Encoding UTF8 -Path $pageFile -Value $pageTsx
OK ("Wrote: {0}" -f $pageFile)

# 3) Optional: ensure API route is dynamic
Sec "Ensuring API is dynamic (optional)"
$apiRoute = Join-Path $appDir "api\reports\board\route.ts"
if (Test-Path $apiRoute) {
  $api = Get-Content $apiRoute -Raw
  if ($api -notmatch 'export const dynamic\s*=\s*["'']force-dynamic["'']') {
    $api = 'export const dynamic = "force-dynamic";' + "`r`n" + $api
    Set-Content -Encoding UTF8 -Path $apiRoute -Value $api
    OK "Injected 'force-dynamic' into API route."
  } else {
    OK "API already dynamic."
  }
} else {
  Warn ("API route not found at {0} (skipping)." -f $apiRoute)
}

# 4) Deploy (remote build)
Sec "Deploying (remote build)"
vercel pull --environment=production --yes | Out-Host
$deployOut = & vercel deploy --prod --yes 2>&1
$exit = $LASTEXITCODE
$deployOut | Out-Host
if ($exit -ne 0) { throw ("Vercel deploy failed ({0})" -f $exit) }

# Extract production URL
$prodUrl = ($deployOut | Select-String -Pattern 'https://[^ ]+\.vercel\.app').Matches.Value | Select-Object -Last 1
if (-not $prodUrl) { throw "Could not detect production URL from deploy output." }
OK ("Production URL: {0}" -f $prodUrl)

# 5) Verify prod + custom domain
Sec "Verifying endpoints"
$urls = @(
  "$prodUrl/reports/board?org=demo-2128873b",
  "https://truvern.com/reports/board?org=demo-2128873b"
)
$badCustom = $false
foreach ($u in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $u -Method GET -TimeoutSec 25 -Headers @{ "Cache-Control"="no-cache" } -ErrorAction Stop
    Write-Host ("{0} -> {1}" -f $u, [int]$r.StatusCode) -ForegroundColor Green
  } catch {
    Write-Host ("{0} -> FAILED ({1})" -f $u, $_.Exception.Message) -ForegroundColor Yellow
    if ($u -like "https://truvern.com/*") { $badCustom = $true }
  }
}

# 6) Auto-alias if custom domain not serving the new deploy
if ($badCustom) {
  Sec "Custom domain not serving the new deploy — setting alias"
  & vercel alias set $prodUrl truvern.com 2>&1 | Out-Host
  & vercel alias set $prodUrl www.truvern.com 2>&1 | Out-Host
  OK "Alias updated. Re-test truvern.com shortly."
}

OK "Phase 68 complete."
Write-Host "Open:" -ForegroundColor Yellow
Write-Host (" - {0}/reports/board?org=demo-2128873b" -f $prodUrl) -ForegroundColor Yellow
Write-Host " - https://truvern.com/reports/board?org=demo-2128873b" -ForegroundColor Yellow
