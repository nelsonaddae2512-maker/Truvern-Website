# Phase74-UIFoundation-Fixed.ps1 — brand tokens + header + shared Button + deploy
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Sec($t){ Write-Host "`n=== $t ===" -ForegroundColor Cyan }
function Ok($t){ Write-Host $t -ForegroundColor Green }

Sec "Detecting app directory"
if     (Test-Path "app")             { $appDir = "app" }
elseif (Test-Path "apps\tprm\app")   { $appDir = "apps\tprm\app" }
elseif (Test-Path "apps\website\app"){ $appDir = "apps\website\app" }
else { throw "App directory not found" }
Ok "Using $appDir"

# 1) Tailwind config
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
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#1E40AF",
          50: "#EFF6FF",
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
        accent: "#10B981"
      },
      fontFamily: { ui: ["system-ui","Segoe UI","Inter","sans-serif"] },
      boxShadow: { card: "0 1px 2px rgba(0,0,0,0.05)" }
    }
  },
  plugins: []
};
'@
Set-Content -Encoding UTF8 -Path .\tailwind.config.js -Value $tw
Ok "tailwind.config.js written"

# 2) Globals
Sec "Writing globals.css"
$globals = Join-Path $appDir "globals.css"
$css = @'
@tailwind base;
@tailwind components;
@tailwind utilities;

body { @apply bg-gray-50 text-gray-900 font-ui; }
a { @apply text-brand-700 hover:text-brand-800 underline-offset-2 hover:underline; }

.container-page { @apply mx-auto w-full max-w-6xl px-4 sm:px-6 lg:px-8; }
.card { @apply rounded-lg border border-gray-200 bg-white p-5 shadow-card; }
.btn  { @apply inline-flex items-center justify-center rounded-md px-3 py-1.5 text-sm font-medium; }
.btn-brand { @apply btn bg-brand-700 text-white hover:bg-brand-800; }
.btn-ghost { @apply btn border border-gray-300 bg-gray-50 text-gray-800 hover:bg-gray-100; }
'@
Set-Content -Encoding UTF8 -Path $globals -Value $css
Ok "globals.css ready"

# 3) Components/Button.tsx
Sec "Creating components/Button.tsx"
New-Item -ItemType Directory -Force -Path "components" | Out-Null
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
Set-Content -Encoding UTF8 -Path ".\components\Button.tsx" -Value $btn
Ok "Button component created"

# 4) Components/SiteHeader.tsx
Sec "Creating components/SiteHeader.tsx"
$hdr = @'
import Link from "next/link";

export function SiteHeader() {
  return (
    <header className="border-b border-gray-200 bg-white/80 backdrop-blur">
      <div className="container-page h-14 flex items-center justify-between">
        <Link href="/" className="text-brand-800 font-semibold tracking-tight">Truvern</Link>
        <nav className="hidden sm:flex items-center gap-4 text-sm">
          <Link href="/trust">Trust Network</Link>
          <Link href="/vendors">Vendors</Link>
          <Link href="/pricing">Pricing</Link>
          <Link href="/docs">Docs</Link>
          <Link href="/login" className="btn-ghost">Login</Link>
          <Link href="/subscribe" className="btn-brand">Get Started</Link>
        </nav>
      </div>
    </header>
  );
}
'@
Set-Content -Encoding UTF8 -Path ".\components\SiteHeader.tsx" -Value $hdr
Ok "Header component created"

# 5) Patch layout.tsx
Sec "Patching layout.tsx"
$layout = Join-Path $appDir "layout.tsx"
if (-not (Test-Path $layout)) { throw "layout.tsx not found" }
$content = Get-Content $layout -Raw
if ($content -notmatch "globals.css") {
  $content = 'import "./globals.css";' + "`r`n" + $content
}
if ($content -notmatch "SiteHeader") {
  $content = 'import { SiteHeader } from "../../components/SiteHeader";' + "`r`n" + $content
}
if ($content -notmatch "container-page") {
  $content = $content -replace "(<body[^>]*>)",'$1`r`n    <SiteHeader />`r`n    <div className="container-page py-8">'
  $content = $content -replace "(</body>)",'    </div>`r`n  $1'
}
Set-Content -Encoding UTF8 -Path $layout -Value $content
Ok "layout.tsx updated"

# 6) Deploy safely
Sec "Deploying via NPX"
npx vercel pull --environment=production --yes | Out-Host
$deployOut = & npx vercel deploy --prod --yes 2>&1
$code = $LASTEXITCODE
$deployOut | Out-Host
if ($code -ne 0) { throw "Vercel deploy failed ($code)" }

$prod = ($deployOut | Select-String -Pattern "https://[^ ]+\.vercel\.app").Matches.Value | Select-Object -Last 1
if (-not $prod) { $prod = "https://truvern.com" }

Ok "Deployment finished"
Write-Host "UI:  https://truvern.com/reports/board?org=demo-2128873b" -ForegroundColor Yellow
Write-Host "API: https://truvern.com/api/reports/board?org=demo-2128873b" -ForegroundColor Yellow
Write-Host "CSV: https://truvern.com/api/reports/board?org=demo-2128873b`"&format=csv" -ForegroundColor Yellow
Ok "Phase 74 fixed and complete."
