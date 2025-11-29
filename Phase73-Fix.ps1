# Phase73-Fix.ps1 — re-write page.tsx literally to remove escaped sequences
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }

# 1) Locate the app dir
Sec "Locating app directory"
if     (Test-Path "app")             { $appDir = "app" }
elseif (Test-Path "apps\tprm\app")   { $appDir = "apps\tprm\app" }
elseif (Test-Path "apps\website\app"){ $appDir = "apps\website\app" }
else { throw "App dir not found" }
Ok "Using $appDir"

# 2) Write clean literal page.tsx
Sec "Rewriting app/reports/board/page.tsx"
$page = Join-Path $appDir "reports\board\page.tsx"
New-Item -ItemType Directory -Force -Path (Split-Path $page) | Out-Null

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

function ScoreBadge({ value }: { value: number | string }) {
  const n = typeof value === "number" ? value : Number(value);
  if (!isFinite(n))
    return <span className="inline-flex items-center rounded-full bg-gray-200 px-2 py-0.5 text-sm font-semibold text-gray-700">N/A</span>;
  const cls =
    n >= 85 ? "bg-green-100 text-green-800" :
    n >= 70 ? "bg-yellow-100 text-yellow-800" :
              "bg-red-100 text-red-800";
  return <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-sm font-semibold ${cls}`}>{n}%</span>;
}

function RiskBadge({ risk }: { risk: string }) {
  const r = (risk || "").toLowerCase();
  const map: Record<string,string> = {
    low: "bg-green-100 text-green-800",
    moderate: "bg-yellow-100 text-yellow-800",
    medium: "bg-yellow-100 text-yellow-800",
    high: "bg-red-100 text-red-800",
  };
  const cls = map[r] || "bg-gray-200 text-gray-700";
  return <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-sm font-semibold ${cls}`}>{risk || "Unknown"}</span>;
}

function fmtDate(iso?: string) {
  try { return iso ? new Date(iso).toLocaleString() : "—"; }
  catch { return "—"; }
}

export default function BoardSummary() {
  const params = useSearchParams();
  const org = params.get("org") ?? "demo-2128873b";
  const apiUrl = useMemo(() => `/api/reports/board?org=${encodeURIComponent(org)}`, [org]);

  const [data, setData] = useState<BoardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [err, setErr] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    (async () => {
      try {
        setLoading(true);
        setErr(null);
        const res = await fetch(apiUrl, { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        if (alive) setData(json);
      } catch (e: any) {
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
      const m = String(d.getMonth()+1).padStart(2,"0");
      const day = String(d.getDate()).padStart(2,"0");
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
    <main className="mx-auto max-w-3xl px-6 py-8">
      <h1 className="text-2xl font-semibold tracking-tight">📊 Board Summary</h1>
      <p className="mt-1 text-sm text-gray-600">
        Organization: <span className="font-medium">{org}</span>
      </p>

      <section className="mt-6 rounded-lg border border-gray-200 bg-white p-5 shadow-sm">
        {loading && (
          <div className="space-y-3">
            <div className="h-3 w-40 animate-pulse rounded bg-gray-200" />
            <div className="h-8 w-28 animate-pulse rounded bg-gray-200" />
            <div className="h-3 w-28 animate-pulse rounded bg-gray-200" />
            <div className="h-8 w-24 animate-pulse rounded bg-gray-200" />
          </div>
        )}

        {err && <p className="text-sm text-red-700">Error: {err}</p>}

        {!loading && !err && (
          <div>
            <dl className="grid grid-cols-[180px_1fr] gap-y-2">
              <dt className="text-sm text-gray-600">Overall Score</dt>
              <dd><ScoreBadge value={data?.overall ?? "N/A"} /></dd>
              <dt className="text-sm text-gray-600">Risk Tier</dt>
              <dd><RiskBadge risk={data?.risk ?? "Unknown"} /></dd>
              <dt className="text-sm text-gray-600">Last Updated</dt>
              <dd className="text-sm">{fmtDate(data?.updated || data?.requestedAt)}</dd>
            </dl>

            {data?.message && <p className="mt-3 text-sm text-gray-800">{data.message}</p>}

            <div className="mt-4 flex items-center gap-3">
              <a
                className="inline-flex items-center rounded border border-gray-300 bg-gray-50 px-3 py-1.5 text-sm font-medium text-gray-800 hover:bg-gray-100"
                href={`/api/reports/board?org=${encodeURIComponent(org)}`}
              >
                View JSON
              </a>
              <button
                onClick={downloadCsv}
                className="inline-flex items-center rounded border border-gray-300 bg-gray-50 px-3 py-1.5 text-sm font-medium text-gray-800 hover:bg-gray-100"
              >
                Download CSV
              </button>
            </div>
          </div>
        )}
      </section>

      <footer className="mt-8 text-sm text-gray-500">© Truvern • Board Summary</footer>
    </main>
  );
}
'@

Set-Content -Encoding UTF8 -Path $page -Value $pageTsx
Ok "Fixed $page"

# 3) Redeploy cleanly
Sec "Deploying clean build"
npx vercel pull --environment=production --yes | Out-Host
npx vercel deploy --prod --yes
Ok "Phase 73-Fix complete."
