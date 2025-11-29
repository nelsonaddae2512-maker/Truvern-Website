# Phase65-BoardSummaryUI.ps1 — recreate working /reports/board page and redeploy
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function OK($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Warning $t }

function Resolve-AppDir {
  foreach ($p in @("app","apps\tprm\app","apps\website\app")) {
    if (Test-Path $p) { return $p }
  }
  throw "App directory not found."
}
$appDir = Resolve-AppDir
OK "Using app dir: $appDir"

# --- Rebuild /reports/board/page.tsx ---
Sec "Rebuilding /reports/board/page.tsx"
$boardDir = Join-Path $appDir "reports\board"
New-Item -ItemType Directory -Force -Path $boardDir | Out-Null
$pageFile = Join-Path $boardDir "page.tsx"

@'
export const dynamic = "force-dynamic";
export const revalidate = 0;

import React from "react";

async function getBoardData(org: string) {
  const res = await fetch(`/api/reports/board?org=${org}`, { cache: "no-store" });
  if (!res.ok) {
    return { overall: "N/A", risk: "Unknown", message: "Failed to load board data." };
  }
  return res.json();
}

export default async function BoardSummary({ searchParams }: { searchParams: { org?: string } }) {
  const org = searchParams?.org || "demo-2128873b";
  const data = await getBoardData(org);

  return (
    <main style={{
      fontFamily: "system-ui,Segoe UI,Roboto,Arial",
      padding: "2rem",
      maxWidth: "960px",
      margin: "0 auto",
      lineHeight: 1.6
    }}>
      <h1 style={{color:"#0d9488"}}>📊 Board Summary Report</h1>
      <p>Organization ID: <strong>{org}</strong></p>
      <section style={{
        background:"#f9fafb",
        padding:"1rem",
        borderRadius:"8px",
        marginTop:"1.5rem",
        boxShadow:"0 1px 2px rgba(0,0,0,0.05)"
      }}>
        <h2>Overall Score</h2>
        <p style={{fontSize:"1.25rem"}}><strong>{data.overall ?? "N/A"}</strong></p>

        <h2>Risk Tier</h2>
        <p style={{fontSize:"1.25rem"}}><strong>{data.risk ?? "Unknown"}</strong></p>

        <p style={{marginTop:"1rem",color:"#6b7280"}}>
          Data generated dynamically from the <code>/api/reports/board</code> endpoint.
        </p>
      </section>

      <footer style={{marginTop:"2rem",fontSize:"0.9rem",color:"#6b7280"}}>
        <p>© Truvern Board Analytics • Phase 65 UI Build</p>
      </footer>
    </main>
  );
}
'@ | Set-Content -Encoding UTF8 $pageFile

OK "Rebuilt: $pageFile"

# --- Redeploy remotely ---
Sec "Redeploying with new board summary UI"
vercel pull --environment=production --yes | Out-Host
iex "vercel deploy --prod --yes"
if ($LASTEXITCODE -ne 0) { throw "Vercel deploy failed ($LASTEXITCODE)" }

OK "Phase65 complete — BoardSummary UI deployed."
Write-Host "→ Visit: https://truvern.com/reports/board?org=demo-2128873b" -ForegroundColor Yellow
