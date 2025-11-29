# Phase75-UIComponents.ps1 — add Card, Badge, Title components + /reports/board/preview UI
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function OK($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Warning $t }

# 1) Locate App Router dir
Sec "Locating App Router directory"
$choices = @("app", "apps\tprm\app", "apps\website\app")
$appDir = $null
foreach($c in $choices){ if(Test-Path $c){ $appDir = $c; break } }
if(-not $appDir){ throw "App directory not found." }
OK ("Using app dir: " + $appDir)

# 2) Ensure components folder
$cmpRoot = Join-Path (Split-Path -Parent $appDir) "components"
if(-not (Test-Path $cmpRoot)){ New-Item -ItemType Directory -Path $cmpRoot | Out-Null }
$uiDir = Join-Path $cmpRoot "ui"
if(-not (Test-Path $uiDir)){ New-Item -ItemType Directory -Path $uiDir | Out-Null }

# 3) Write Card.tsx
Sec "Writing components/ui/Card.tsx"
$cardFile = Join-Path $uiDir "Card.tsx"
$cardTsx = @'
import * as React from "react";
import clsx from "clsx";

export function Card({ className = "", children }: React.PropsWithChildren<{ className?: string }>) {
  return (
    <div className={clsx(
      "rounded-xl border border-zinc-200/60 bg-white shadow-sm dark:border-zinc-800/60 dark:bg-zinc-900",
      className
    )}>
      {children}
    </div>
  );
}

export function CardHeader({ className = "", children }: React.PropsWithChildren<{ className?: string }>) {
  return <div className={clsx("px-5 pt-5", className)}>{children}</div>;
}

export function CardTitle({ className = "", children }: React.PropsWithChildren<{ className?: string }>) {
  return <h3 className={clsx("text-lg font-semibold tracking-tight", className)}>{children}</h3>;
}

export function CardContent({ className = "", children }: React.PropsWithChildren<{ className?: string }>) {
  return <div className={clsx("px-5 pb-5", className)}>{children}</div>;
}

export function CardFooter({ className = "", children }: React.PropsWithChildren<{ className?: string }>) {
  return <div className={clsx("px-5 pb-5 border-t border-zinc-100 dark:border-zinc-800", className)}>{children}</div>;
}
'@
Set-Content -Encoding UTF8 $cardFile $cardTsx
OK "Card.tsx written."

# 4) Write Badge.tsx
Sec "Writing components/ui/Badge.tsx"
$badgeFile = Join-Path $uiDir "Badge.tsx"
$badgeTsx = @'
import clsx from "clsx";

type Variant = "default" | "success" | "warning" | "danger" | "info";

export function Badge({ children, className = "", variant = "default" }: {
  children: React.ReactNode;
  className?: string;
  variant?: Variant;
}) {
  const base = "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium";
  const look: Record<Variant, string> = {
    default: "bg-zinc-100 text-zinc-800 dark:bg-zinc-800 dark:text-zinc-100",
    success: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/40 dark:text-emerald-200",
    warning: "bg-amber-100 text-amber-800 dark:bg-amber-900/40 dark:text-amber-200",
    danger:  "bg-rose-100 text-rose-800 dark:bg-rose-900/40 dark:text-rose-200",
    info:    "bg-blue-100 text-blue-800 dark:bg-blue-900/40 dark:text-blue-200",
  };
  return <span className={clsx(base, look[variant], className)}>{children}</span>;
}
'@
Set-Content -Encoding UTF8 $badgeFile $badgeTsx
OK "Badge.tsx written."

# 5) Write Title.tsx
Sec "Writing components/ui/Title.tsx"
$titleFile = Join-Path $uiDir "Title.tsx"
$titleTsx = @'
import clsx from "clsx";

export function Title({ children, className = "" }: React.PropsWithChildren<{ className?: string }>) {
  return <h1 className={clsx("text-2xl md:text-3xl font-bold tracking-tight", className)}>{children}</h1>;
}
'@
Set-Content -Encoding UTF8 $titleFile $titleTsx
OK "Title.tsx written."

# 6) Add a safe PREVIEW page that uses these components (no change to live page.tsx)
Sec "Writing preview page: /reports/board/preview"
$previewDir = Join-Path $appDir "reports\board"
if(-not (Test-Path $previewDir)){ New-Item -ItemType Directory -Path $previewDir -Force | Out-Null }
$previewFile = Join-Path $previewDir "preview.tsx"
$previewTsx = @'
"use client";
import * as React from "react";
import { useEffect, useState } from "react";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/Card";
import { Badge } from "@/components/ui/Badge";
import { Title } from "@/components/ui/Title";

type Row = { key: string; value: string | number | null };
type Payload = { org: string; overall: number; risk: string; items: Row[]; generatedAt?: string };

function toUrl(org: string, csv: boolean) {
  const base = "";
  const q = encodeURIComponent(org);
  return csv ? `/api/reports/board?org=${q}&format=csv` : `/api/reports/board?org=${q}`;
}

export default function BoardPreview({ searchParams }: { searchParams: { org?: string } }) {
  const org = searchParams?.org ?? "demo-2128873b";
  const [data, setData] = useState<Payload | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    let alive = true;
    async function run() {
      try {
        setLoading(true); setErr(null);
        const res = await fetch(toUrl(org, false), { cache: "no-store" });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const json = await res.json();
        if (alive) setData(json);
      } catch (e: any) {
        if (alive) setErr(e?.message ?? "Failed to load");
      } finally {
        if (alive) setLoading(false);
      }
    }
    run();
    return () => { alive = false; };
  }, [org]);

  return (
    <main className="container mx-auto max-w-5xl px-6 py-8">
      <div className="mb-6">
        <Title>Board Summary</Title>
        <p className="text-sm text-zinc-500">Organization: <span className="font-medium">{org}</span></p>
      </div>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-3">
            Current Risk
            <Badge variant={data?.risk === "High" ? "danger" : data?.risk === "Medium" ? "warning" : "success"}>
              {data?.risk ?? "—"}
            </Badge>
            <span className="ml-auto text-sm text-zinc-500">
              Overall: <span className="font-semibold">{typeof data?.overall === "number" ? Math.round(data!.overall) : "—"}</span>
            </span>
          </CardTitle>
        </CardHeader>
        <CardContent>
          {loading && <div className="text-sm text-zinc-500">Loading…</div>}
          {err && <div className="text-sm text-rose-600">Error: {err}</div>}
          {!loading && !err && (
            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {(data?.items ?? []).slice(0, 8).map((r) => (
                <div key={r.key} className="rounded-lg border border-zinc-200/60 p-3 text-sm dark:border-zinc-800/60">
                  <div className="text-zinc-500">{r.key}</div>
                  <div className="font-medium">{String(r.value ?? "—")}</div>
                </div>
              ))}
            </div>
          )}

          <div className="mt-6 flex flex-wrap gap-3">
            <a href={toUrl(org, false)} className="underline text-blue-600">View JSON</a>
            <a href={toUrl(org, true)}  className="underline text-blue-600">Download CSV</a>
          </div>
        </CardContent>
      </Card>

      <footer className="mt-8 text-xs text-zinc-500">© Truvern • Phase 75 Preview</footer>
    </main>
  );
}
'@
Set-Content -Encoding UTF8 $previewFile $previewTsx
OK "Preview page written."

# 7) Done
OK "Phase 75 component pack + preview page created."
Write-Host "Next: deploy with your working script: .\Phase74-NodeDirect-PlainFix.ps1" -ForegroundColor Yellow
Write-Host "Then open: https://truvern.com/reports/board/preview?org=demo-2128873b" -ForegroundColor Yellow
