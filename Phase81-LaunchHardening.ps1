# =========================================
# Phase81-LaunchHardening.ps1  (FINAL/STABLE)
# Security headers + robots/sitemap + health + 404/error + deploy + FAST checks
# =========================================
param([switch]$NoDeploy)
$ErrorActionPreference = 'Stop'

# --- SAFE working dir (cross-version) ---
try {
  if ($PSCommandPath) { $ScriptPath = $PSCommandPath }
  elseif ($MyInvocation.MyCommand.Definition) { $ScriptPath = $MyInvocation.MyCommand.Definition }
  elseif ($MyInvocation.InvocationName) { $ScriptPath = (Resolve-Path $MyInvocation.InvocationName).Path }
  else { throw "Cannot determine script path." }
  $Root = Split-Path -Parent $ScriptPath
  Set-Location -Path $Root
  Write-Host "`nRunning from: $Root`n"
} catch {
  Write-Host "❌ Failed to detect script path: $($_.Exception.Message)"
  throw
}

# --- Helpers ---
function Set-FileIfChanged {
  param([string]$Path,[string]$Content,[string]$Encoding='UTF8')
  $write=$true
  if (Test-Path -LiteralPath $Path) {
    $existing = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue
    if ($existing -eq $Content) { $write=$false }
  }
  if ($write) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Set-Content -LiteralPath $Path -Value $Content -Encoding $Encoding
    Write-Host "Updated $Path"
  } else { Write-Host "Ok   $Path (no change)" }
}
function Get-VercelInvoker {
  try { $cmd = Get-Command vercel -ErrorAction SilentlyContinue } catch {}
  if ($cmd -and $cmd.Source) { return $cmd.Source }
  return "npx vercel"
}

# --- Paths ---
$appDir     = Join-Path $Root 'app'
$apiDir     = Join-Path $appDir 'api'
$healthDir  = Join-Path $apiDir  'health'
$publicDir  = Join-Path $Root 'public'
$vercelJson = Join-Path $Root 'vercel.json'
$sitemapTs  = Join-Path $appDir 'sitemap.ts'
$robotsTxt  = Join-Path $publicDir 'robots.txt'
$notFound   = Join-Path $appDir '404.tsx'
$errorPage  = Join-Path $appDir 'error.tsx'

# --- Ensure folders ---
@($appDir,$apiDir,$healthDir,$publicDir) | ForEach-Object {
  if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ | Out-Null }
}

# --- vercel.json ---
$vercelJsonContent = @'
{
  "headers": [
    { "source": "/api/(.*)", "headers": [
      { "key": "Cache-Control", "value": "no-store" }
    ]},
    { "source": "/api/reports/board(.*)", "headers": [
      { "key": "Cache-Control", "value": "no-store" },
      { "key": "X-Content-Type-Options", "value": "nosniff" }
    ]},
    { "source": "/_next/static/(.*)", "headers": [
      { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
    ]},
    { "source": "/(.*\\.(?:js|css|png|jpg|jpeg|gif|svg|webp|ico|woff|woff2))", "headers": [
      { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
    ]},
    { "source": "/(.*)", "headers": [
      { "key": "Strict-Transport-Security", "value": "max-age=31536000; includeSubDomains; preload" },
      { "key": "X-Frame-Options", "value": "DENY" },
      { "key": "X-Content-Type-Options", "value": "nosniff" },
      { "key": "Referrer-Policy", "value": "strict-origin-when-cross-origin" },
      { "key": "Permissions-Policy", "value": "geolocation=(), microphone=(), camera=()" },
      { "key": "Content-Security-Policy", "value": "default-src 'self' https: data: blob:; img-src 'self' https: data: blob:; style-src 'self' 'unsafe-inline' https:; script-src 'self' 'unsafe-eval' 'unsafe-inline' https:; connect-src 'self' https:; font-src 'self' https: data:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'" }
    ]}
  ]
}
'@
Set-FileIfChanged -Path $vercelJson -Content $vercelJsonContent

# --- robots.txt ---
$robots = "User-agent: *`r`nAllow: /`r`nSitemap: https://truvern.com/sitemap.xml"
Set-FileIfChanged -Path $robotsTxt -Content $robots -Encoding 'ASCII'

# --- app/sitemap.ts ---
$sitemap = @'
import type { MetadataRoute } from "next";
export default function sitemap(): MetadataRoute.Sitemap {
  const base = process.env.APP_URL ?? "https://truvern.com";
  const routes = ["/", "/vendors", "/trust", "/dashboard"];
  const now = new Date().toISOString();
  return routes.map((p) => ({
    url: `${base}${p}`,
    lastModified: now,
    changeFrequency: "daily",
    priority: p === "/" ? 1 : 0.7
  }));
}
'@
Set-FileIfChanged -Path $sitemapTs -Content $sitemap

# --- /api/health ---
$healthRoute = @'
import { NextResponse } from "next/server";
export const runtime = "edge";
export async function GET() {
  return NextResponse.json({ ok: true, service: "truvern", ts: Date.now() }, { status: 200 });
}
'@
Set-FileIfChanged -Path (Join-Path $healthDir 'route.ts') -Content $healthRoute

# --- 404 + error pages ---
$notFoundContent = @'
export default function NotFound() {
  return (
    <div style={{padding:24}}>
      <h1>Page not found</h1>
      <p>Try the dashboard or vendors list.</p>
      <a href="/">Go home</a>
    </div>
  );
}
'@
Set-FileIfChanged -Path $notFound -Content $notFoundContent

$errorContent = @'
"use client";
export default function GlobalError({ error }: { error: Error & { digest?: string } }) {
  return (
    <html><body style={{padding:24}}>
      <h1>Something went wrong</h1>
      <p>{error?.message ?? "Unexpected error"}</p>
      <a href="/">Back home</a>
    </body></html>
  );
}
'@
Set-FileIfChanged -Path $errorPage -Content $errorContent

# --- Deploy ---
if (-not $NoDeploy) {
  $V = Get-VercelInvoker
  Write-Host "`n=== vercel pull (production) ==="
  & $V pull --environment=production --yes
  Write-Host "`n=== vercel deploy --prod ==="
  & $V deploy --prod --yes
} else {
  Write-Host "`n(NoDeploy) Skipping deploy step."
}

# --- FAST post-deploy checks (HttpClient HEAD, 8s timeout, TLS 1.2) ---
Add-Type -AssemblyName System.Net.Http
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
Write-Host "`n=== Post-deploy checks ==="
$urls = @(
  "https://truvern.com/api/health",
  "https://truvern.com/robots.txt",
  "https://truvern.com/sitemap.xml"
)
$failed = @()
$handler = New-Object System.Net.Http.HttpClientHandler
$client  = New-Object System.Net.Http.HttpClient($handler)
$client.Timeout = [TimeSpan]::FromSeconds(8)

foreach ($u in $urls) {
  try {
    $req = New-Object System.Net.Http.HttpRequestMessage ([System.Net.Http.HttpMethod]::Head), $u
    $res = $client.SendAsync($req).Result
    $code = [int]$res.StatusCode
    if ($code -ge 200 -and $code -lt 400) { Write-Host ("OK  {0}  {1}" -f $code, $u) }
    else { Write-Host ("WARN {0}  {1}" -f $code, $u); $failed += $u }
  } catch { Write-Host ("ERR       {0}  -> {1}" -f $u, $_.Exception.Message); $failed += $u }
}
$client.Dispose(); $handler.Dispose()
if ($failed.Count -gt 0) { Write-Warning "Some checks failed:"; $failed | ForEach-Object { Write-Host " - $_" } }
else { Write-Host "`n✅ Phase 81 complete: security headers + health + robots/sitemap deployed.`n" }

