# Phase325D-FixClerkMiddlewareAndSignIn.ps1
# Fixes Clerk middleware protect() shape, fixes sign-in wildcard path handling, resolves manifest conflict,
# and ensures Activity feed points to /api/activity-feed.
# MUST run from project root (not system32).

$ErrorActionPreference = "Stop"

function Write-Section($t) {
  Write-Host ""
  Write-Host "=== $t ===" -ForegroundColor Cyan
}

$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $root "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir "Phase325D-FixClerkMiddlewareAndSignIn-$ts.log"

Start-Transcript -Path $log | Out-Null

try {
  Write-Section "Project root"
  Write-Host $root

  Write-Section "Patch middleware.ts (Clerk protect compatibility)"
  $middlewarePath = Join-Path $root "middleware.ts"

  if (-not (Test-Path -LiteralPath $middlewarePath)) {
    throw "middleware.ts not found at $middlewarePath"
  }

  $middlewareContent = @"
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/",
  "/pricing(.*)",
  "/contact(.*)",
  "/trust-network(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",

  // static/public assets
  "/favicon.ico",
  "/robots.txt",
  "/sitemap.xml",
  "/site.webmanifest",
  "/manifest.webmanifest",
  "/icon-192.png",
  "/icon-512.png",
  "/apple-touch-icon.png",
]);

export default clerkMiddleware((auth, req) => {
  if (isPublicRoute(req)) return;

  const a: any = auth as any;

  // Support both Clerk middleware shapes across versions:
  // - auth.protect()
  // - auth().protect()
  if (typeof a?.protect === "function") {
    a.protect();
    return;
  }

  if (typeof a === "function") {
    const res = a();
    if (typeof res?.protect === "function") {
      res.protect();
      return;
    }
  }

  // Fail closed if Clerk changes again.
  throw new Error("Clerk middleware auth protect() not available");
});

export const config = {
  matcher: [
    "/((?!_next|.*\\.(?:css|js|map|png|jpg|jpeg|gif|svg|ico|webp|txt|xml|json|woff2?)).*)",
    "/(api|trpc)(.*)",
  ],
};
"@

  Set-Content -LiteralPath $middlewarePath -Value $middlewareContent -Encoding UTF8
  Write-Host "Patched: $middlewarePath" -ForegroundColor Green

  Write-Section "Resolve manifest conflict (app/manifest.ts vs public/manifest.webmanifest)"
  $publicManifest = Join-Path $root "public\manifest.webmanifest"
  if (Test-Path -LiteralPath $publicManifest) {
    Remove-Item -LiteralPath $publicManifest -Force
    Write-Host "Deleted: $publicManifest (kept app\manifest.ts)" -ForegroundColor Yellow
  } else {
    Write-Host "No public\manifest.webmanifest found (ok)"
  }

  Write-Section "Ensure activity feed panel uses /api/activity-feed"
  $panelPath = Join-Path $root "components\activity-feed-panel.tsx"
  if (Test-Path -LiteralPath $panelPath) {
    $raw = Get-Content -LiteralPath $panelPath -Raw
    $raw2 = $raw `
      -replace 'const\s+base\s*=\s*["'']\/api\/activity["''];', 'const base = "/api/activity-feed";' `
      -replace 'const\s+base\s*=\s*["'']\/api\/activity-feed["''];', 'const base = "/api/activity-feed";'
    if ($raw2 -ne $raw) {
      Set-Content -LiteralPath $panelPath -Value $raw2 -Encoding UTF8
      Write-Host "Patched: $panelPath" -ForegroundColor Green
    } else {
      Write-Host "No changes needed: $panelPath"
    }
  } else {
    Write-Host "Missing: $panelPath (skipped)" -ForegroundColor Yellow
  }

  Write-Section "Next.js clean + restart reminder"
  Write-Host "Run these next:" -ForegroundColor Cyan
  Write-Host "  cd $root"
  Write-Host "  Remove-Item -Recurse -Force .\.next -ErrorAction SilentlyContinue"
  Write-Host "  npm run dev"
}
finally {
  Stop-Transcript | Out-Null
  Write-Host ""
  Write-Host "Log written: $log" -ForegroundColor DarkGray
}
