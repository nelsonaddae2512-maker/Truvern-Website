# Phase73-Tailwind.ps1 — add Tailwind, wire globals/layout, restyle Board UI, deploy with NPX
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Host $t -ForegroundColor Yellow }

# 1) Detect app dir + package manager
Sec "Detecting project structure"
if     (Test-Path "app")             { $appDir = "app" }
elseif (Test-Path "apps\tprm\app")   { $appDir = "apps\tprm\app" }
elseif (Test-Path "apps\website\app"){ $appDir = "apps\website\app" }
else { throw "App Router directory not found." }
Ok "Using app dir: $appDir"

$usePnpm = Test-Path ".\pnpm-lock.yaml"
$pm = if ($usePnpm) { "pnpm" } else { "npm" }
Ok "Package manager: $pm"

# 2) Install Tailwind + PostCSS
Sec "Installing Tailwind CSS + PostCSS"
if ($pm -eq "pnpm") {
  pnpm add -D tailwindcss postcss autoprefixer
} else {
  npm i -D tailwindcss postcss autoprefixer
}

# 3) Write tailwind.config.js (content globs include monorepo)
Sec "Writing tailwind.config.js"
$tw = @'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./apps/**/*.{js,ts,jsx,tsx,mdx}"
  ],
  theme: { extend: {} },
  plugins: [],
};
'@
Set-Content -Encoding UTF8 -Path .\tailwind.config.js -Value $tw

# 4) Write postcss.config.js
Sec "Writing postcss.config.js"
$postcss = @'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
'@
Set-Content -Encoding UTF8 -Path .\postcss.config.js -Value $postcss

# 5) Ensure globals.css has Tailwind directives
Sec "Ensuring app/globals.css"
$globals = Join-Path $appDir "globals.css"
$css = @'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* App-wide base styles */
:root { color-scheme: light; }
html, body { height: 100%; }
body { @apply bg-gray-50 text-gray-900; }
a { @apply text-blue-700 underline-offset-2 hover:underline; }
'@
New-Item -ItemType File -Path $globals -Force | Out-Null
Set-Content -Encoding UTF8 -Path $globals -Value $css
Ok "Wrote $globals"

# 6) Ensure layout.tsx imports globals.css
Sec "Ensuring app/layout.tsx"
$layout = Join-Path $appDir "layout.tsx"
if (-not (Test-Path $layout)) {
  $layoutCode = @'
export const metadata = { title: "Truvern" };

import "./globals.css";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen bg-gray-50 text-gray-900">{children}</body>
    </html>
  );
}
'@
  Set-Content -Encoding UTF8 -Path $layout -Value $layoutCode
  Ok "Created $layout"
} else {
  # make sure it imports globals.css (idempotent)
  $t = Get-Content $layout -Raw
  if ($t -notmatch 'globals\.css') {
    $t = "import `"$($appDir -replace '\\','/')/globals.css`";`r`n" + $t
    Set-Content -Encoding UTF8 -Path $layout -Value $t
    Ok "Injected globals import into existing layout.tsx"
  } else { Ok "layout.tsx already imports globals.css" }
}

# 7) Tailwind-styled Board page
Sec "Writing Tailwind version of /reports/board/page.tsx"
$boardDir = Join-Path $appDir "reports\board"
New-Item -ItemType Directory -Force -Path $boardDir | Out-Null
$page = Join-Path $boardDir "page.tsx"

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
  if (!isFinite(n)) return <span className="inline-flex items-center rounded-full bg-gray-200 px-2 py-0.5 text-sm font-semibold text-gray-700">N/A</span>;
  const cls = n >= 85
    ? "bg-green-100 text-green-800"
    : n >= 70
      ? "bg-yellow-100 text-yellow-800"
      : "bg-red-100 text-red-800";
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
  try { return iso ? new Date(iso).toLocaleString() : "—"; } catch { return "—"; }
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
        setLoading(true); setErr(null);
        const res = await fetch(apiUrl, { cache: "no-store" });
        if (!res.ok) throw new Error(\`HTTP \${res.status}\`);
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
      const res = await fetch(\`/api/reports/board?org=\${encodeURIComponent(org)}&format=csv\`, { cache: "no-store" });
      if (!res.ok) throw new Error(\`HTTP \${res.status}\`);
      const blob = await res.blob();
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement("a");
      const d = new Date();
      const y = d.getFullYear();
      const m = String(d.getMonth()+1).padStart(2,"0");
      const day = String(d.getDate()).padStart(2,"0");
      a.href = url;
      a.download = \`\${org}-board-\${y}-\${m}-\${day}.csv\`;
      document.body.appendChild(a); a.click(); a.remove();
      window.URL.revokeObjectURL(url);
    } catch (e:any) {
      alert(e?.message ?? "CSV download failed");
    }
  }

  return (
    <main className="mx-auto max-w-3xl px-6 py-8">
      <h1 className="text-2xl font-semibold tracking-tight">📊 Board Summary</h1>
      <p className="mt-1 text-sm text-gray-600">Organization: <span className="font-medium">{org}</span></p>

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
              <a className="inline-flex items-center rounded border border-gray-300 bg-gray-50 px-3 py-1.5 text-sm font-medium text-gray-800 hover:bg-gray-100"
                 href={`/api/reports/board?org=${encodeURIComponent(org)}`}>
                View JSON
              </a>
              <button onClick={downloadCsv}
                      className="inline-flex items-center rounded border border-gray-300 bg-gray-50 px-3 py-1.5 text-sm font-medium text-gray-800 hover:bg-gray-100">
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
Ok "Wrote $page"

# 8) Deploy with NPX vercel
Sec "Deploying (remote build)"
npx vercel pull --environment=production --yes | Out-Host
$out = & npx vercel deploy --prod --yes 2>&1
$exit = $LASTEXITCODE
$out | Out-Host
if ($exit -ne 0) { throw "Vercel deploy failed ($exit)" }

# Extract prod URL and show links
$prodUrl = ($out | Select-String -Pattern 'https://[^ ]+\.vercel\.app').Matches.Value | Select-Object -Last 1
if (-not $prodUrl) { $prodUrl = "https://<prod>.vercel.app" }
Ok "Production URL: $prodUrl"

Sec "Open to verify"
Write-Host ("UI  : {0}/reports/board?org=demo-2128873b" -f $prodUrl) -ForegroundColor Yellow
Write-Host ("JSON: https://truvern.com/api/reports/board?org=demo-2128873b") -ForegroundColor Yellow
Write-Host ("CSV : https://truvern.com/api/reports/board?org=demo-2128873b&format=csv") -ForegroundColor Yellow

Ok "Phase 73 complete."
