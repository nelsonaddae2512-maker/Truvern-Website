# Phase122a-StyleHotfix.ps1
# Repair Tailwind/PostCSS/Next styling + metadata, rebuild, deploy, and verify HTTP 200s.

$ErrorActionPreference = 'Stop'

# --- Guard: do not run from system32 ---
if ((Get-Location).Path -match '\\Windows\\system32$') {
  throw "Do not run from system32. cd to your project folder and rerun."
}

# --- Paths & logging ---
$root   = (Get-Location).Path
$logs   = Join-Path $root "logs"
if (-not (Test-Path $logs)) { New-Item -ItemType Directory -Path $logs | Out-Null }
$ts     = Get-Date -Format "yyyyMMdd-HHmmss"
$log    = Join-Path $logs "phase122a-style-hotfix-$ts.log"
function Log($m){ $line = "[{0}] {1}" -f (Get-Date).ToString("HH:mm:ss"), $m; $line | Tee-Object -FilePath $log -Append | Out-Host }

Log "=== Phase122a start ==="
Log "Project: $root"

# --- Sanity: package.json present ---
$pkgJson = Join-Path $root "package.json"
if (-not (Test-Path $pkgJson)) { throw "package.json not found in $root" }

# --- Small helpers ---
function Ensure-Dir($p){ if(-not (Test-Path $p)){ New-Item -ItemType Directory -Path $p -Force | Out-Null } }
function WriteUtf8($path, $text){
  Ensure-Dir ([System.IO.Path]::GetDirectoryName($path))
  Set-Content -Path $path -Value $text -Encoding UTF8 -NoNewline
  Log "Wrote: $path"
}
function Run($cmd){
  Log "> $cmd"
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "cmd.exe"
  $psi.Arguments = "/d /c $cmd"
  $psi.WorkingDirectory = $root
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $p = [System.Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()
  ($out + $err) | Tee-Object -FilePath $log -Append | Out-Host
  if ($p.ExitCode -ne 0) { throw ("Command failed ({0}): {1}" -f $p.ExitCode,$cmd) }
}

# --- 1) Tailwind + PostCSS config (safe reset) ---
$tailwindPath = if (Test-Path (Join-Path $root "tailwind.config.ts")) { Join-Path $root "tailwind.config.ts" } else { Join-Path $root "tailwind.config.js" }
$postcssPath  = if (Test-Path (Join-Path $root "postcss.config.cjs")) { Join-Path $root "postcss.config.cjs" } else { Join-Path $root "postcss.config.js" }

$tailwindCfg = @"
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ['./app/**/*.{js,ts,jsx,tsx}','./components/**/*.{js,ts,jsx,tsx}'],
  theme: { extend: {} },
  plugins: [require('@tailwindcss/forms'), require('@tailwindcss/typography')],
};
"@
$postcssCfg = @"
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
"@

WriteUtf8 $tailwindPath $tailwindCfg
WriteUtf8 $postcssPath  $postcssCfg

# --- 2) globals.css present with core directives ---
$appDir = Join-Path $root "app"
Ensure-Dir $appDir
$globalsCss = Join-Path $appDir "globals.css"
if (-not (Test-Path $globalsCss)) {
  $g = "@tailwind base;`r`n@tailwind components;`r`n@tailwind utilities;`r`n:root{--tv-bg:#0b1220;--tv-fg:#e5e7eb} html,body{min-height:100%;background:#0b1220;color:#e5e7eb}"
  WriteUtf8 $globalsCss $g
} else {
  $g = Get-Content $globalsCss -Raw
  if ($g -notmatch '@tailwind base')       { $g = "@tailwind base;`r`n$g" }
  if ($g -notmatch '@tailwind components') { $g = $g + "`r`n@tailwind components;" }
  if ($g -notmatch '@tailwind utilities')  { $g = $g + "`r`n@tailwind utilities;" }
  WriteUtf8 $globalsCss $g
}

# --- 3) layout.tsx: import CSS + minimal metadata ---
$layoutPath = Join-Path $appDir "layout.tsx"
$layoutSafe = @"
import './globals.css';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Truvern — Vendor Trust Network',
  description: 'TPRM trust network, vendor assessments, and board reporting.',
  viewport: 'width=device-width, initial-scale=1',
  themeColor: '#0f172a',
  icons: { icon: '/favicon.ico' }
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang='en'>
      <body>{children}</body>
    </html>
  );
}
"@
if (-not (Test-Path $layoutPath)) {
  WriteUtf8 $layoutPath $layoutSafe
} else {
  $t = Get-Content $layoutPath -Raw
  if ($t -notmatch "import\s+['""]\.\/globals\.css['""]") { $t = "import './globals.css';`r`n" + $t }
  if ($t -notmatch "export\s+const\s+metadata") { $t = $layoutSafe }
  WriteUtf8 $layoutPath $t
}

# --- 4) next.config.js (no assetPrefix/basePath) ---
$nextCfgPath = Join-Path $root "next.config.js"
$nextCfg = @"
/** @type {import('next').NextConfig} */
const nextConfig = { reactStrictMode: true };
module.exports = nextConfig;
"@
WriteUtf8 $nextCfgPath $nextCfg

# --- 5) deps install + build ---
Run "pnpm add -D tailwindcss postcss autoprefixer @tailwindcss/forms @tailwindcss/typography"
Run "pnpm install --no-frozen-lockfile"
Run "pnpm run build"

# --- 6) vercel deploy (assumes CLI installed) ---
try {
  & vercel whoami 2>&1 | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Log "Not logged in, launching device login..."
    & vercel login | Tee-Object -FilePath $log -Append | Out-Host
    Read-Host "Complete Vercel login in the browser, then press Enter"
  }
} catch { }

# Link is idempotent—safe to re-run.
Run "vercel link --yes"
Run "vercel --prod --yes"

# --- 7) verify key routes return 200 + quick CSS emit check ---
$domain = "https://truvern.com"
$routes = @("$domain/","$domain/trust-network","$domain/vendors","$domain/reports/board")
Log "Running HTTP 200 verification..."
$all200 = $true
foreach ($u in $routes) {
  try {
    $r = Invoke-WebRequest -Uri $u -Method GET -MaximumRedirection 5 -TimeoutSec 30
    if ($r.StatusCode -eq 200) { Log ("OK  {0} -> 200" -f $u) } else { Log ("FAIL {0} -> {1}" -f $u,$r.StatusCode); $all200=$false }
  } catch {
    Log ("FAIL {0} -> {1}" -f $u,$_.Exception.Message)
    $all200 = $false
  }
}

try {
  $home = Invoke-WebRequest -Uri "$domain/" -Method GET -MaximumRedirection 5 -TimeoutSec 30
  $m = [regex]::Match($home.Content, 'href="(/_next/static/css/[^"]+\.css)"')
  if ($m.Success) {
    $cssUrl = "$domain$($m.Groups[1].Value)"
    $cr = Invoke-WebRequest -Uri $cssUrl -Method GET -TimeoutSec 30
    if ($cr.StatusCode -eq 200) { Log "OK  CSS asset 200" } else { Log "FAIL CSS asset -> $($cr.StatusCode)"; $all200=$false }
  } else {
    Log "WARN: No external CSS link found. (If pages still show HTML-only, Tailwind didn’t run or import is missing.)"
    $all200 = $false
  }
} catch {
  Log "FAIL CSS check -> $($_.Exception.Message)"
  $all200 = $false
}

Log "=== Summary ==="
if ($all200) { Log "All routes + CSS asset OK ✅" } else { Log "Some checks failed. Inspect $log" }
Write-Host "`nDone. Log: $log"
