# Phase74-UIFoundation.ps1 — Tailwind brand tokens + header + shared Button + deploy
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Warn($t){ Write-Host $t -ForegroundColor Yellow }

Sec "Detecting App Router directory"
if     (Test-Path "app")             { $appDir = "app" }
elseif (Test-Path "apps\tprm\app")   { $appDir = "apps\tprm\app" }
elseif (Test-Path "apps\website\app"){ $appDir = "apps\website\app" }
else { throw "App Router directory not found." }
Ok "Using app dir: $appDir"

# 1) Tailwind config with brand tokens
Sec "Writing tailwind.config.js (brand tokens)"
$tw = @'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./apps/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Truvern brand
        brand: {
          DEFAULT: "#1E40AF",   // primary (blue-800)
          50:  "#EFF6FF",
          100: "#DBEAFE",
          200: "#BFDBFE",
          300: "#93C5FD",
          400: "#60A5FA",
          500: "#3B82F6",
          600: "#2563EB",
          700: "#1D4ED8",
          800: "#1E40AF",
          900: "#1E3A8A"
        },
        accent: "#10B981",     // emerald-500
      },
      fontFamily: {
        ui: ["system-ui","Segoe UI","Roboto","Inter","Arial","sans-serif"]
      },
      boxShadow: {
        card: "0 1px 2px rgba(0,0,0,0.05)"
      }
    },
  },
  plugins: [],
};
'@
Set-Content -Encoding UTF8 -Path .\tailwind.config.js -Value $tw
Ok "tailwind.config.js updated"

# 2) Globals — consistent base styling
Sec "Ensuring globals.css base styles"
$globals = Join-Path $appDir "globals.css"
$css = @'
@tailwind base;
@tailwind components;
@tailwind utilities;

/* Base */
:root { color-scheme: light; }
html, body { height: 100%; }
body { @apply bg-gray-50 text-gray-900 font-ui; }
a { @apply text-brand-700 hover:text-brand-800 underline-offset-2 hover:underline; }

/* Simple container helper */
.container-page { @apply mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8; }
.card { @apply rounded-lg border border-gray-200 bg-white p-5 shadow-card; }
.btn  { @apply inline-flex items-center justify-center rounded-md px-3 py-1.5 text-sm font-medium; }
.btn-brand { @apply btn bg-brand-700 text-white hover:bg-brand-800; }
.btn-ghost { @apply btn border border-gray-300 bg-gray-50 text-gray-800 hover:bg-gray-100; }
'@
New-Item -ItemType File -Path $globals -Force | Out-Null
Set-Content -Encoding UTF8 -Path $globals -Value $css
Ok "globals.css written"

# 3) Components: Button and Header
Sec "Writing shared Button component"
$componentsDir = "components"
New-Item -ItemType Directory -Force -Path $componentsDir | Out-Null
$btnFile = Join-Path $componentsDir "Button.tsx"
$btn = @'
import * as React from "react";
type Props = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "brand" | "ghost";
};
export function Button({ variant="brand", className="", ...rest }: Props) {
  const base = variant === "brand" ? "btn-brand" : "btn-ghost";
  return <button className={`${base} ${className}`} {...rest} />;
}
'@
Set-Content -Encoding UTF8 -Path $btnFile -Value $btn
Ok "components/Button.tsx written"

Sec "Writing SiteHeader"
$hdrFile = Join-Path $componentsDir "SiteHeader.tsx"
$hdr = @'
import Link from "next/link";

export function SiteHeader() {
  return (
    <header className="border-b border-gray-200 bg-white/80 backdrop-blur">
      <div className="container-page h-14 flex items-center justify-between">
        <Link href="/" className="text-brand-800 font-semibold tracking-tight">Truvern</Link>
        <nav className="hidden sm:flex items-center gap-4 text-sm">
          <Link href="/trust" className="hover:text-brand-800">Trust Network</Link>
          <Link href="/vendors" className="hover:text-brand-800">Vendors</Link>
          <Link href="/pricing" className="hover:text-brand-800">Pricing</Link>
          <Link href="/docs" className="hover:text-brand-800">Docs</Link>
          <Link href="/login" className="btn-ghost">Login</Link>
          <Link href="/subscribe" className="btn-brand">Get Started</Link>
        </nav>
      </div>
    </header>
  );
}
'@
Set-Content -Encoding UTF8 -Path $hdrFile -Value $hdr
Ok "components/SiteHeader.tsx written"

# 4) Patch layout.tsx to include header + container (idempotent)
Sec "Patching layout.tsx"
$layout = Join-Path $appDir "layout.tsx"
if (-not (Test-Path $layout)) { throw "Expected $layout but not found." }
$orig = Get-Content $layout -Raw

if ($orig -notmatch 'globals\.css') {
  $orig = 'import "./globals.css";' + "`r`n" + $orig
}

if ($orig -notmatch 'SiteHeader') {
  $orig = 'import { SiteHeader } from "../../components/SiteHeader";' + "`r`n" + $orig
}

# Wrap children with container-page (lightweight)
if ($orig -notmatch 'container-page') {
  $orig = $orig -replace '(<body[^>]*>)','`$1' + "`r`n    <SiteHeader />" + "`r`n    <div className=""container-page py-8"">"
  $orig = $orig -replace '(</body>)','    </div>' + "`r`n  `$1"
}

Set-Content -Encoding UTF8 -Path $layout -Value $orig
Ok "layout.tsx patched"

# 5) Tidy Board page to use Button (safe if missing)
Sec "Enhancing Board page with Button component"
$board = Join-Path $appDir "reports\board\page.tsx"
if (Test-Path $board) {
  $bp = Get-Content $board -Raw
  if ($bp -notmatch 'from "../..\/\.\.\/components\/Button"'
      -and $bp -notmatch 'from ".*components\/Button"') {
    $bp = 'import { Button } from "../../../components/Button";' + "`r`n" + $bp
  }
  # Replace plain <button> with <Button/> roughly (best-effort, non-destructive):
  $bp = $bp -replace '<button([^>]*)className="[^"]*"(.*?)>','<Button$1$2>'
  $bp = $bp -replace '</button>','</Button>'
  Set-Content -Encoding UTF8 -Path $board -Value $bp
  Ok "Board page updated to use <Button/> (best-effort)"
} else {
  Warn "Board page not found — skipped Button enhancement."
}

# 6) Deploy with NPX (no shim)
Sec "Deploying"
npx vercel pull --environment=production --yes | Out-Host
$out = & npx vercel deploy --prod --yes 2>&1
$code = $LASTEXITCODE
$out | Out-Host
if ($code -ne 0) { throw "Vercel deploy failed ($code)" }

$prod = ($out | Select-String -Pattern 'https://[^ ]+\.vercel\.app').Matches.Value | Select-Object -Last 1
if (-not $prod) { $prod = "<prod-url>" }
Ok "Production: $prod"

Sec "Open to verify"
Write-Host ("UI   : https://truvern.com/reports/board?org=demo-2128873b") -ForegroundColor Yellow
Write-Host ("JSON : https://truvern.com/api/reports/board?org=demo-2128873b") -ForegroundColor Yellow
Write-Host ("CSV  : https://truvern.com/api/reports/board?org=demo-2128873b&format=csv") -ForegroundColor Yellow

Ok "Phase 74 complete."
