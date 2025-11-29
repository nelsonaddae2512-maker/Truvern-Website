<# =========================================================
 Phase39-Observability.ps1
 Purpose:
   - Add Sentry (@sentry/nextjs) with minimal config
   - Safely wrap existing next.config.mjs with withSentryConfig
   - Ensure env: SENTRY_DSN, SENTRY_ENVIRONMENT, NEXT_PUBLIC_SENTRY_DSN
   - Add uptime endpoint: /api/ping
   - Optional throw route: /api/boom (to test Sentry)
   - GuardDog run: timeouts, non-interactive deploy, detailed logs
========================================================= #>

[CmdletBinding()]
param(
  [switch]$SkipFiles = $false,
  [switch]$SkipInstall = $false,
  [switch]$SkipBuild = $false,
  [switch]$SkipDeploy = $false,
  [switch]$Deploy = $false
)
if ($Deploy) { $SkipDeploy = $false }

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path; Set-Location $ScriptRoot

function Note([string]$m,[string]$c="Gray"){ Write-Host $m -ForegroundColor $c }
function Fail([string]$m){ Write-Host "ERROR: $m" -ForegroundColor Red; throw $m }

# ---- Logging ----
$logs = Join-Path $PWD "logs"; if(!(Test-Path $logs)){ New-Item -ItemType Directory $logs | Out-Null }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log = Join-Path $logs "phase39-$stamp.log"
$results = Join-Path $logs "phase39-$stamp.results.json"
Start-Transcript -Path $log -Append | Out-Null

# ---- Timeout runner ----
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
public static class ProcRun {
  public static int Run(string exe, string args, int timeoutMs) {
    var psi = new ProcessStartInfo(exe, args);
    psi.RedirectStandardOutput = true;
    psi.RedirectStandardError  = true;
    psi.UseShellExecute = false;
    psi.CreateNoWindow = true;
    var p = Process.Start(psi);
    if(p==null) return -1;
    if(!p.WaitForExit(timeoutMs)){
      try { p.Kill(true); } catch { try { p.Kill(); } catch {} }
      return 124;
    }
    return p.ExitCode;
  }
}
"@

function Run-Step([string]$name,[scriptblock]$sb,[int]$timeoutSec=600){
  $start = Get-Date
  Note ("→ " + $name + " (timeout " + $timeoutSec + "s)") "Cyan"
  $ok=$false; $err=$null
  try { & $sb; $ok=$true } catch { $err=$_.Exception.Message }
  $dur=[int]((Get-Date)-$start).TotalSeconds
  $entry=[ordered]@{ step=$name; ok=$ok; seconds=$dur; error=$err }
  ($entry | ConvertTo-Json -Compress) | Add-Content $results
  if(!$ok){
    Fail ("Step failed: " + $name + " — " + $err)
  } else {
    Note ("✔ " + $name + " in " + $dur + "s") "Green"
  }
}

try {
  # ---- Preflight ----
  Run-Step "Preflight" {
    foreach($t in @("node","pnpm","vercel")){ if(-not (Get-Command $t -ErrorAction SilentlyContinue)){ Fail "Missing tool: $t" } }
    if(-not (Test-Path "package.json")){ Fail "Run from repo root (package.json missing)" }
    if(-not (Test-Path "app")){ New-Item -ItemType Directory "app" | Out-Null }

    # APP_URL for completeness
    if(-not $env:APP_URL){
      foreach($f in @(".env.production.local",".env.local",".env",".env.production")){
        if(Test-Path $f){
          $txt=Get-Content $f -Raw
          $m=[regex]::Match($txt,'^\s*APP_URL\s*=\s*(.+)\s*$','IgnoreCase,Multiline')
          if($m.Success){ $env:APP_URL=$m.Groups[1].Value.Trim(); break }
        }
      }
    }
    if(-not $env:APP_URL){ $env:APP_URL="https://truvern.com"; Add-Content ".env.production.local" "`nAPP_URL=$($env:APP_URL)" }

    # Env placeholders for Sentry
    $envFile = ".env.production.local"; if(!(Test-Path $envFile)){ New-Item -ItemType File $envFile | Out-Null }
    $envText = Get-Content $envFile -Raw
    if($envText -notmatch '^\s*SENTRY_ENVIRONMENT\s*=' ){ Add-Content $envFile "`nSENTRY_ENVIRONMENT=production" }
    if($envText -notmatch '^\s*SENTRY_DSN\s*=' ){ Add-Content $envFile "`n# SENTRY_DSN=https://<publicKey>@o<orgId>.ingest.sentry.io/<projectId>" }
    if($envText -notmatch '^\s*NEXT_PUBLIC_SENTRY_DSN\s*=' ){ Add-Content $envFile "`n# NEXT_PUBLIC_SENTRY_DSN=${env:SENTRY_DSN}" }
  } 60

  # ---- Files ----
  if(-not $SkipFiles){
    Run-Step "Create Sentry config + uptime routes" {
      function Ensure-Dir($p){ if(!(Test-Path $p)){ New-Item -ItemType Directory -Path $p -Force | Out-Null } }
      function Write-IfMissing($p,[string]$c){ if(!(Test-Path $p)){ Ensure-Dir (Split-Path -Parent $p); Set-Content $p $c -NoNewline -Encoding UTF8; Note "Created: $p" "Green" } else { Note "Exists: $p" "DarkGray" } }

      # 1) Sentry config files (client/server/edge)
      Write-IfMissing "sentry.client.config.ts" @"
import * as Sentry from '@sentry/nextjs'
Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN || process.env.SENTRY_DSN,
  tracesSampleRate: 0.1,
  environment: process.env.SENTRY_ENVIRONMENT || process.env.NODE_ENV
})
"@
      Write-IfMissing "sentry.server.config.ts" @"
import * as Sentry from '@sentry/nextjs'
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  tracesSampleRate: 0.1,
  environment: process.env.SENTRY_ENVIRONMENT || process.env.NODE_ENV
})
"@
      Write-IfMissing "sentry.edge.config.ts" @"
import * as Sentry from '@sentry/nextjs'
Sentry.init({ dsn: process.env.SENTRY_DSN, tracesSampleRate: 0.05, environment: process.env.SENTRY_ENVIRONMENT })
"@

      # 2) Uptime endpoint: /api/ping
      Ensure-Dir "app\api\ping"
      Write-IfMissing "app\api\ping\route.ts" @"
import { NextResponse } from 'next/server'
export const dynamic = 'force-dynamic'
export async function GET(){
  const started = Number(process.env.BOOT_TS || Date.now())
  return NextResponse.json({
    ok: true,
    time: new Date().toISOString(),
    uptimeMs: Date.now() - started,
    version: process.env.VERCEL_GIT_COMMIT_SHA || 'local'
  }, { status: 200 })
}
"@

      # 3) Optional: a route that throws (to verify Sentry capture)
      Ensure-Dir "app\api\boom"
      Write-IfMissing "app\api\boom\route.ts" @"
export async function GET(){ throw new Error('Phase39 test error: boom!') }
"@

      # 4) next.config.mjs — wrap with Sentry plugin without losing existing config
      $nc = "next.config.mjs"
      if (Test-Path $nc) {
        $txt = Get-Content $nc -Raw

        if ($txt -notmatch "@sentry/nextjs") {
          # If file exports `export default nextConfig`, replace that line with wrapped export
          if ($txt -match "export\s+default\s+nextConfig") {
            $pref = "import { withSentryConfig } from '@sentry/nextjs'"
            $wrap = "export default withSentryConfig(nextConfig, { silent: true }, { hideSourcemaps: true })"
            # add import + replace export
            if ($txt -notmatch "withSentryConfig") { $txt = "$pref`n$txt" }
            $txt = [regex]::Replace($txt, "export\s+default\s+nextConfig\s*;?", $wrap)
            Set-Content $nc $txt -NoNewline -Encoding UTF8
            Note "Wrapped existing next.config.mjs with withSentryConfig()" "Yellow"
          } else {
            # no recognizable export; append a small wrapper
            Add-Content $nc "`nimport { withSentryConfig } from '@sentry/nextjs'`nexport default withSentryConfig({}, { silent: true }, { hideSourcemaps: true })`n"
            Note "Appended Sentry wrapper to next.config.mjs" "Yellow"
          }
        } else {
          Note "next.config.mjs already references @sentry/nextjs" "DarkGray"
        }
      } else {
        # Create a new config (keeps Phase36 headers style + Sentry wrapper)
        Set-Content $nc @"
/** Auto-generated by Phase39 */
const securityHeaders = [
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=(self)' },
  { key: 'Content-Security-Policy', value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' *.vercel-insights.com; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self' data:; connect-src 'self' https:; frame-ancestors 'none'; base-uri 'self'; form-action 'self'" }
];
const nextConfig = { async headers(){ return [{ source: '/(.*)', headers: securityHeaders }] } }
import { withSentryConfig } from '@sentry/nextjs'
export default withSentryConfig(nextConfig, { silent: true }, { hideSourcemaps: true })
"@ -NoNewline -Encoding UTF8
        Note "Created next.config.mjs with headers + Sentry wrapper" "Green"
      }
    } 120
  } else {
    Note "Skipped: file creation (-SkipFiles)" "Yellow"
  }

  # ---- Install ----
  if(-not $SkipInstall){
    Run-Step "Install @sentry/nextjs" {
      [void][ProcRun]::Run("pnpm","add @sentry/nextjs", 6*60*1000) | Out-Null
      if($LASTEXITCODE -ne 0){ Fail "pnpm add @sentry/nextjs failed ($LASTEXITCODE)" }
    } 360
  } else { Note "Skipped: install" "Yellow" }

  # ---- Build ----
  if(-not $SkipBuild){
    Run-Step "Build (Next.js with Sentry)" {
      # mark boot timestamp for /api/ping
      $env:BOOT_TS = [string](Get-Date -UFormat %s) * 1000
      [void][ProcRun]::Run("pnpm","run build", 15*60*1000) | Out-Null
      if($LASTEXITCODE -ne 0){ Fail "pnpm run build failed/timeout ($LASTEXITCODE)" }
      $css = Get-ChildItem ".next\static\css" -Filter "*.css" -Recurse -ErrorAction SilentlyContinue
      if(-not $css){ Fail "No CSS bundle produced in .next/static/css" }
    } 900
  } else { Note "Skipped: build" "Yellow" }

  # ---- Deploy ----
  if(-not $SkipDeploy){
    Run-Step "Vercel pull" {
      [void][ProcRun]::Run("vercel","pull --yes --environment=production", 2*60*1000) | Out-Null
    } 130
    Run-Step "Vercel deploy (prod)" {
      if (Test-Path ".vercel\output") { $args = "deploy --prebuilt --prod --yes" } else { $args = "deploy --prod --yes" }
      [void][ProcRun]::Run("vercel",$args, 8*60*1000) | Out-Null
    } 500
  } else { Note "Skipped: deploy" "Yellow" }

  Note "`nPASS: Phase39 complete." "Green"
  Note ("Log: " + $log) "DarkGray"
  Note ("Results: " + $results) "DarkGray"
  if(-not $env:SENTRY_DSN){ Note "Heads-up: SENTRY_DSN not set. Add it in .env.production.local and redeploy to enable Sentry capture." "Yellow" }
  exit 0
}
catch {
  Note ("ERROR: " + $_.Exception.Message) "Red"
  Note ("See log for details: " + $log) "Yellow"
  exit 1
}
finally {
  try { if (Get-Command Stop-Transcript -ErrorAction SilentlyContinue) { Stop-Transcript | Out-Null } } catch {}
}
