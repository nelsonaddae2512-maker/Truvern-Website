Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Warning $t }

# 0) Locate app dir
Sec "Locating App Router directory"
$appDir = "app"
if (-not (Test-Path $appDir)) { throw "App directory '$appDir' not found." }
Ok "Using app dir: $appDir"

# 1) Ensure components folder
Sec "Ensuring components folder"
$cmp = "components"
if (-not (Test-Path $cmp)) { New-Item -ItemType Directory -Path $cmp | Out-Null }
Ok "Components at: $cmp"

# 2) Write KPIStat.tsx
Sec "Writing components/KPIStat.tsx"
$kpi = @'
"use client";
import React from "react";

type Props = {
  label: string;
  value: string | number;
  sub?: string;
};

export default function KPIStat({ label, value, sub }: Props) {
  return (
    <div className="rounded-lg border border-zinc-200/70 bg-white p-4 shadow-sm dark:border-zinc-800/70 dark:bg-zinc-900">
      <div className="text-xs uppercase tracking-wide text-zinc-500 dark:text-zinc-400">{label}</div>
      <div className="mt-1 text-2xl font-semibold text-zinc-900 dark:text-zinc-100">{value}</div>
      {sub ? <div className="mt-1 text-xs text-zinc-500 dark:text-zinc-400">{sub}</div> : null}
    </div>
  );
}
'@
Set-Content -Encoding UTF8 -Path "components/KPIStat.tsx" -Value $kpi
Ok "KPIStat.tsx written"

# 3) Write TrendBar.tsx
Sec "Writing components/TrendBar.tsx"
$trend = @'
"use client";
import React from "react";

type Props = {
  pct: number; // 0..100
  tone?: "ok" | "warn" | "bad";
  label?: string;
};

export default function TrendBar({ pct, tone = "ok", label }: Props) {
  const color =
    tone === "bad" ? "bg-rose-500" :
    tone === "warn" ? "bg-amber-500" :
    "bg-emerald-500";
  const width = Math.max(0, Math.min(100, pct));
  return (
    <div>
      {label ? <div className="mb-1 text-xs text-zinc-600 dark:text-zinc-300">{label}</div> : null}
      <div className="h-2 w-full rounded bg-zinc-200 dark:bg-zinc-800">
        <div className={`h-2 rounded ${color}`} style={{ width: `${width}%` }} />
      </div>
    </div>
  );
}
'@
Set-Content -Encoding UTF8 -Path "components/TrendBar.tsx" -Value $trend
Ok "TrendBar.tsx written"

# 4) Patch preview page to render KPI tiles + trend bars
Sec "Patching preview page"
$previewDir = Join-Path $appDir "reports\board\preview"
$pageFile = Join-Path $previewDir "page.tsx"
if (-not (Test-Path $pageFile)) {
  throw "Preview page not found at $pageFile. Make sure the file exists (app/reports/board/preview/page.tsx)."
}

$pageTsx = @'
"use client";

import React, { useEffect, useState } from "react";
import KPIStat from "@/components/KPIStat";
import TrendBar from "@/components/TrendBar";

type ScoreRow = { id: string; score: number; title?: string; };
type BoardPayload = {
  org: string;
  overall: number;
  risk?: string;
  items: ScoreRow[];
  generatedAt?: string;
};

export default function BoardPreviewPage() {
  const [data, setData] = useState<BoardPayload | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [alive, setAlive] = useState(true);

  useEffect(() => {
    setAlive(true);
    const params = new URLSearchParams(window.location.search);
    const org = params.get("org") || "demo-2128873b";
    const base = "/api/reports/board";
    const url = `${base}?org=${encodeURIComponent(org)}`;

    (async () => {
      try {
        const res = await fetch(url, { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        if (alive) setData(json);
      } catch (e:any) {
        if (alive) setErr(e?.message || "Failed to load");
      }
    })();

    return () => { setAlive(false); };
  }, []);

  const cards = (() => {
    if (!data) return null;
    const items = data.items || [];

    const overall = Math.round(data.overall ?? 0);
    const high = items.filter(x => (x.score ?? 0) >= 80).length;
    const medium = items.filter(x => (x.score ?? 0) >= 50 && (x.score ?? 0) < 80).length;
    const low = items.filter(x => (x.score ?? 0) < 50).length;

    return (
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KPIStat label="Overall Score" value={`${overall}`} sub="0–100 (higher is better)" />
        <KPIStat label="High Scores" value={high} sub=">= 80" />
        <KPIStat label="Medium" value={medium} sub="50–79" />
        <KPIStat label="Low" value={low} sub="< 50" />
      </div>
    );
  })();

  const trends = (() => {
    if (!data) return null;
    const items = (data.items || []).slice(0, 4); // top 4 for compact view
    return (
      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        {items.map((it, idx) => {
          const pct = Math.round(Math.max(0, Math.min(100, it.score ?? 0)));
          const tone = pct >= 80 ? "ok" : pct >= 50 ? "warn" : "bad";
          return (
            <div key={it.id || idx} className="rounded-lg border border-zinc-200/70 bg-white p-4 shadow-sm dark:border-zinc-800/70 dark:bg-zinc-900">
              <div className="mb-2 text-sm font-medium text-zinc-800 dark:text-zinc-100">
                {it.title || `Item ${idx + 1}`}
              </div>
              <TrendBar pct={pct} tone={tone as any} label={`Score: ${pct}`} />
            </div>
          );
        })}
      </div>
    );
  })();

  return (
    <main className="container mx-auto max-w-6xl px-6 py-8">
      <h1 className="mb-2 text-2xl font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">
        Board Summary – Preview
      </h1>
      <p className="mb-6 text-sm text-zinc-600 dark:text-zinc-300">
        Live preview powered by <code className="rounded bg-zinc-100 px-1 py-0.5 dark:bg-zinc-800">/api/reports/board</code>
      </p>

      {err ? (
        <div className="mb-6 rounded border border-rose-300 bg-rose-50 p-3 text-rose-700 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-300">
          {err}
        </div>
      ) : null}

      {cards ? <section className="mb-8">{cards}</section> : null}

      <section className="space-y-4">
        <div className="text-sm font-medium text-zinc-700 dark:text-zinc-200">Key Areas</div>
        {trends}
      </section>

      <section className="mt-8 flex flex-wrap gap-4 text-sm">
        <a className="underline" href={`/api/reports/board?org=${encodeURIComponent((data?.org)||"demo-2128873b")}`}>View JSON</a>
        <a className="underline" href={`/api/reports/board?org=${encodeURIComponent((data?.org)||"demo-2128873b")}&format=csv`}>Download CSV</a>
      </section>

      <footer className="mt-10 text-xs text-zinc-500 dark:text-zinc-400">
        Truvern • Phase 76 KPI Tiles + Trends
      </footer>
    </main>
  );
}
'@
Set-Content -Encoding UTF8 -Path $pageFile -Value $pageTsx
Ok "Preview page patched: $pageFile"

# 5) Deploy using your stable script
Sec "Deploying (Phase74 plain fix)"
if (-not (Test-Path ".\Phase74-NodeDirect-PlainFix.ps1")) {
  Warn "Phase74-NodeDirect-PlainFix.ps1 not found. Skipping deploy."
} else {
  & .\Phase74-NodeDirect-PlainFix.ps1
}
