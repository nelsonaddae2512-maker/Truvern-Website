# Create the script file
New-Item -ItemType File -Path .\Phase72-BoardUIPolish.ps1 -Force | Out-Null

# Write the script contents (single-quoted here-string preserves ${...} literally)
$script = @'
# Phase72-BoardUIPolish.ps1 — polish Board UI + client CSV download; deploy via npx vercel
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Host $t -ForegroundColor Yellow }

# 1) Locate App Router directory
Sec "Locating App Router directory"
$appCandidates = @("app","apps\tprm\app","apps\website\app") | Where-Object { Test-Path $_ }
if(-not $appCandidates){ throw "No App Router dir found (checked: app, apps\tprm\app, apps\website\app)." }
$appDir = $appCandidates[0]
Ok ("Using app dir: {0}" -f $appDir)

# 2) Write polished page.tsx (no server changes required)
Sec "Writing polished page: /reports/board/page.tsx"
$boardDir = Join-Path $appDir "reports\board"
New-Item -ItemType Directory -Force -Path $boardDir | Out-Null
$pageFile = Join-Path $boardDir "page.tsx"

$pageTsx = @'
"use client";

import { useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";

type BoardData = {
  org: string;
  overall: number | string;
  risk: string;
  message?: string;
  updated?: string;
  requestedAt?: string;
};

function badgeStyle(bg: string, text: string = "#111827") {
  return {
    display: "inline-block",
    padding: "0.25rem 0.5rem",
    borderRadius: "999px",
    background: bg,
    color: text,
    fontWeight: 600,
    fontSize: 14,
    lineHeight: 1,
  } as const;
}

function scoreBadge(val: number | string) {
  const n = typeof val === "number" ? val : Number(val);
  if (!isFinite(n)) return <span style={badgeStyle("#E5E7EB")}>N/A</span>;
  const bg = n >= 85 ? "#DCFCE7" : n >= 70 ? "#FEF9C3" : "#FEE2E2";
  const color = n >= 85 ? "#166534" : n >= 70 ? "#92400E" : "#991B1B";
  return <span style={badgeStyle(bg, color)}>{n}%</span>;
}

function riskBadge(risk: string) {
  const r = (risk || "").toLowerCase();
  if (r === "low")     return <span style={badgeStyle("#DCFCE7", "#166534")}>Low</span>;
  if (r === "moderate" || r === "medium")
                      return <span style={badgeStyle("#FEF9C3", "#92400E")}>Moderate</span>;
  if (r === "high")    return <span style={badgeStyle("#FEE2E2", "#991B1B")}>High</span>;
  return <span style={badgeStyle("#E5E7EB")}>{risk || "Unknown"}</span>;
}

function fmtDate(iso?: string) {
  try {
    return iso ? new Date(iso).toLocaleString() : "—";
  } catch { return "—"; }
}

export default function BoardSummaryPage() {
  const params = useSearchParams();
  const org = params.get("org") ?? "demo-2128873b";

  // Use relative path; no NEXT_PUBLIC_BASE_URL needed
  const apiUrl = useMemo(() => {
    const q = new URLSearchParams({ org });
    return `/api/reports/board?${q.toString()}`;
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

  async function downloadCsv() {
    try {
      const res = await fetch(`/api/reports/board?org=${encodeURIComponent(org)}&format=csv`, { cache: "no-store" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const blob = await res.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      const d = new Date();
      const y = d.getFullYear();
      const m = String(d.getMonth()+1).padStart(2, "0");
      const day = String(d.getDate()).padStart(2, "0");
      a.href = url;
      a.download = `${org}-board-${y}-${m}-${day}.csv`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      window.URL.revokeObjectURL(url);
    } catch (e:any) {
      alert(e?.message ?? "CSV download failed");
    }
  }

  return (
    <main style={{ fontFamily: "system-ui, Segoe UI, Roboto, Arial", padding: "2rem", maxWidth: 960, margin: "0 auto" }}>
      <h1 style={{ marginBottom: "0.25rem" }}>📊 Board Summary</h1>
      <p style={{ color: "#6b7280", marginBottom: "1.25rem" }}>
        Organization: <strong>{org}</strong>
      </p>

      <section style={{ background: "#ffffff", border: "1px solid #E5E7EB", padding: "1rem", borderRadius: 8, boxShadow: "0 1px 2px rgba(0,0,0,0.03)" }}>
        {loading && (
          <div>
            <div style={{ height: 14, width: 160, background: "#E5E7EB", borderRadius: 4, marginBottom: 8 }} />
            <div style={{ height: 32, width: 120, background: "#E5E7EB", borderRadius: 6 }} />
            <div style={{ height: 14, width: 120, background: "#E5E7EB", borderRadius: 4, marginTop: 16 }} />
            <div style={{ height: 32, width: 110, background: "#E5E7EB", borderRadius: 6, marginTop: 8 }} />
          </div>
        )}

        {err && <p style={{ color: "#b91c1c" }}>Error: {err}</p>}

        {!loading && !err && (
          <div>
            <div style={{ display: "grid", gridTemplateColumns: "200px 1fr", rowGap: "0.5rem" }}>
              <div style={{ color: "#6b7280" }}>Overall Score</div>
              <div>{scoreBadge(data?.overall ?? "N/A")}</div>
              <div style={{ color: "#6b7280" }}>Risk Tier</div>
              <div>{riskBadge(data?.risk ?? "Unknown")}</div>
              <div style={{ color: "#6b7280" }}>Last Updated</div>
              <div>{fmtDate(data?.updated || data?.requestedAt)}</div>
            </div>

            {data?.message && (
              <p style={{ marginTop: "1rem", color: "#374151" }}>{data.message}</p>
            )}

            <div style={{ marginTop: "1rem" }}>
              <a href={`/api/reports/board?org=${encodeURIComponent(org)}`} style={{ marginRight: 12, textDecoration: "underline" }}>
                View JSON
              </a>
              <button onClick={downloadCsv} style={{ padding: "0.5rem 0.75rem", borderRadius: 6, border: "1px solid #D1D5DB", background: "#F9FAFB", cursor: "pointer" }}>
                Download CSV
              </button>
            </div>
          </div>
        )}
      </section>

      <footer style={{ marginTop: "2rem", color: "#6b7280", fontSize: 14 }}>
        © Truvern • Board Summary
      </footer>
    </main>
  );
}
'@

Set-Content -Encoding UTF8 -Path $pageFile -Value $pageTsx
Ok ("Wrote polished UI: {0}" -f $pageFile)

# 3) Deploy with NPX vercel
Sec "Deploying (remote build)"
npx vercel pull --environment=production --yes | Out-Host
$npxOut = & npx vercel deploy --prod --yes 2>&1
$exit = $LASTEXITCODE
$npxOut | Out-Host
if ($exit -ne 0) { throw "Vercel deploy failed ($exit)" }

# Extract prod URL
$prodUrl = ($npxOut | Select-String -Pattern 'https://[^ ]+\.vercel\.app').Matches.Value | Select-Object -Last 1
if (-not $prodUrl) { throw "Could not detect production URL from deploy output." }
Ok ("Production URL: {0}" -f $prodUrl)

# 4) Print test links
Sec "Open these to verify"
Write-Host ("Prod UI   : {0}/reports/board?org=demo-2128873b" -f $prodUrl) -ForegroundColor Yellow
Write-Host ("Custom UI : https://truvern.com/reports/board?org=demo-2128873b") -ForegroundColor Yellow
Write-Host ("JSON      : https://truvern.com/api/reports/board?org=demo-2128873b") -ForegroundColor Yellow
Write-Host ("CSV       : https://truvern.com/api/reports/board?org=demo-2128873b&format=csv") -ForegroundColor Yellow

Ok "Phase 72 complete."
'@

Set-Content -Encoding UTF8 -Path .\Phase72-BoardUIPolish.ps1 -Value $script

# Run it
.\Phase72-BoardUIPolish.ps1
