# repair-build-and-deploy.ps1
$ErrorActionPreference = "Stop"
Set-Location "C:\Users\MR.NELSON\Downloads\truvern"

# --- Logging (keeps window open even on error) ---
$log = Join-Path $PWD ("deploy-log-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt")
Start-Transcript -Path $log -Append | Out-Null
trap {
  Write-Host "`n[!] ERROR: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host "Log saved to: $log" -ForegroundColor Yellow
  Stop-Transcript | Out-Null
  Read-Host "`nPress Enter to close"
  exit 1
}

# --- Helper: write UTF-8 (no BOM) file safely ---
function Write-Utf8NoBom($Path, [string]$Content) {
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

# --- 0) Guard: Vercel token required ---
if (-not $env:VERCEL_TOKEN -or [string]::IsNullOrWhiteSpace($env:VERCEL_TOKEN)) {
  throw "VERCEL_TOKEN is not set. In this window run:`n`n    `$env:VERCEL_TOKEN = `"<your-vercel-token>`"`n"
}

# --- 1) Normalize project config files (Tailwind/PostCSS/Next) ---
# postcss: use .cjs to avoid ESM issues on Vercel
if (Test-Path ".\postcss.config.js") { Remove-Item ".\postcss.config.js" -Force }
Write-Utf8NoBom ".\postcss.config.cjs" @"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
"@

# next.config.mjs (minimal, valid)
Write-Utf8NoBom ".\next.config.mjs" @"
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: { optimizeCss: true }
};
export default nextConfig;
"@

# tailwind.config.js
Write-Utf8NoBom ".\tailwind.config.js" @"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}"
  ],
  theme: { extend: {} },
  plugins: [require("@tailwindcss/typography"), require("@tailwindcss/forms")],
};
"@

# app/globals.css
if (!(Test-Path ".\app")) { New-Item -ItemType Directory ".\app" | Out-Null }
Write-Utf8NoBom ".\app\globals.css" @"
@tailwind base;
@tailwind components;
@tailwind utilities;

html, body { height: 100%; }
body { @apply bg-white text-gray-900 antialiased; }
"@

# Ensure app/layout.tsx imports globals
$layoutPath = ".\app\layout.tsx"
if (Test-Path $layoutPath) {
  $txt = Get-Content $layoutPath -Raw
  if ($txt -notmatch "import\s+['""]\.\/globals\.css['""]") {
    $txt = "import './globals.css';`r`n" + $txt
    Write-Utf8NoBom $layoutPath $txt
  }
} else {
  Write-Utf8NoBom $layoutPath @"
import './globals.css';
export const metadata = { title: 'Truvern' };
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang='en'>
      <body>{children}</body>
    </html>
  );
}
"@
}

# --- 2) Recreate a clean package.json (fixes previous corruption) ---
Write-Utf8NoBom ".\package.json" @"
{
  "name": "truvern",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "15.0.3",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.47",
    "tailwindcss": "^3.4.14",
    "@tailwindcss/forms": "^0.5.9",
    "@tailwindcss/typography": "^0.5.12"
  }
}
"@
Write-Host "✔ package.json written" -ForegroundColor Green

# --- 3) Clean caches & reinstall ---
if (Test-Path ".next") { Remove-Item ".next" -Recurse -Force }
if (Test-Path "node_modules") { Remove-Item "node_modules" -Recurse -Force }
if (Test-Path "package-lock.json") { Remove-Item "package-lock.json" -Force }

Write-Host "`n📦 Installing dependencies..." -ForegroundColor Yellow
npm install --legacy-peer-deps

# --- 4) Build ---
Write-Host "`n🏗️  Building (Next.js)..." -ForegroundColor Yellow
$env:CI = "1"; $env:HUSKY = "0"; $env:NEXT_TELEMETRY_DISABLED = "1"
npm run build

# --- 5) Ensure Vercel CLI shim installed ---
$vercel = Join-Path $env:APPDATA "npm\vercel.cmd"
if (!(Test-Path $vercel)) { npm install -g vercel }
if (!(Test-Path $vercel)) { throw "vercel.cmd not found after install." }

# --- 6) Deploy (no stream capture to avoid NativeCommandError) ---
Write-Host "`n🚀 Deploying (prod)..." -ForegroundColor Cyan
cmd.exe /d /c "`"$vercel`" deploy --yes --prod --scope nelson-addaes-projects --cwd ."

# --- 7) Resolve latest deployment URL & alias domain ---
$urls    = & $vercel list truvern --scope nelson-addaes-projects | Select-String "https://.*\.vercel\.app"
$prodUrl = $urls.Matches.Value | Select-Object -Last 1
if (-not $prodUrl -or $prodUrl.Trim() -eq "") { throw "Could not detect production URL. Check Vercel dashboard." }

Write-Host ("✔ Production URL: " + $prodUrl) -ForegroundColor Green
"PRODUCTION_URL=$prodUrl" | Out-File -Encoding UTF8 -FilePath ".\last-deploy.txt" -Force

Write-Host "🔗 Aliasing truvern.com ..." -ForegroundColor Yellow
cmd.exe /d /c "`"$vercel`" alias set `"$prodUrl`" truvern.com"

# --- 8) Verify 200 on truvern.com ---
try {
  $r = Invoke-WebRequest "https://truvern.com" -UseBasicParsing -TimeoutSec 30
  if ($r.StatusCode -eq 200) {
    Write-Host "✅ https://truvern.com returned 200 OK" -ForegroundColor Green
  } else {
    Write-Host ("⚠ truvern.com returned HTTP " + $r.StatusCode) -ForegroundColor Yellow
  }
} catch {
  Write-Host ("⚠ Verification request failed: " + $_.Exception.Message) -ForegroundColor Yellow
}

Stop-Transcript | Out-Null
Write-Host "`nLog saved to: $log" -ForegroundColor Yellow
Read-Host "`nPress Enter to close"
