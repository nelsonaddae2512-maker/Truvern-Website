<# =====================================================================
 Phase136-CSS-Repair.ps1
 -----------------------------------------------------------------------
 Goal:
   • Fix Tailwind / globals.css wiring for Truvern (Next.js App Router)
   • Clean .next cache to force a fresh CSS build
   • Ensure layout.tsx correctly imports ./globals.css
   • Ensure Tailwind content paths include app/**/* and components/**
   • Rebuild locally, then deploy prebuilt to Vercel
   • Log everything to .\logs\phase136-css-repair-*.log

 IMPORTANT:
   • Run this script from your project root, e.g.
       PS C:\Users\MR.NELSON\Downloads\truvern> .\Phase136-CSS-Repair.ps1
 ===================================================================== #>

# region: Setup & logging ------------------------------------------------------

$ErrorActionPreference = "Stop"

# Ensure we are NOT in system32
if ($PWD.Path -match "System32") {
    Write-Host "`n[ERROR] You are running from System32. Please cd into the project folder first." -ForegroundColor Red
    Write-Host "Example:  cd 'C:\Users\MR.NELSON\Downloads\truvern'" -ForegroundColor Yellow
    exit 1
}

# Basic project sanity check
if (-not (Test-Path ".\package.json") -or -not (Test-Path ".\app")) {
    Write-Host "`n[ERROR] This does not look like the Truvern project root." -ForegroundColor Red
    Write-Host "Make sure you're in the folder that contains package.json and the /app directory." -ForegroundColor Yellow
    exit 1
}

# Logs directory
$logsDir = Join-Path $PWD "logs"
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = Join-Path $logsDir "phase136-css-repair-$timestamp.log"

Start-Transcript -Path $logFile -Force | Out-Null

function Write-Section($title) {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " $title" -ForegroundColor Cyan
    Write-Host "============================================================`n" -ForegroundColor Cyan
}

Write-Section "Phase136 – Truvern CSS / Tailwind Repair"

# endregion --------------------------------------------------------------------


# region: Helper functions -----------------------------------------------------

function Append-LineIfMissing {
    param(
        [string] $FilePath,
        [string] $LineText
    )

    if (-not (Test-Path $FilePath)) {
        Write-Host "[WARN] File not found for Append-LineIfMissing: $FilePath" -ForegroundColor Yellow
        return
    }

    $content = Get-Content $FilePath -Raw
    if ($content -notmatch [Regex]::Escape($LineText)) {
        Write-Host "  + Adding missing line to $FilePath" -ForegroundColor Green
        Add-Content -Path $FilePath -Value $LineText
    }
    else {
        Write-Host "  = Line already present in $FilePath" -ForegroundColor DarkGray
    }
}

function Ensure-ImportGlobalsCss {
    param(
        [string] $LayoutPath
    )

    if (-not (Test-Path $LayoutPath)) {
        Write-Host "[WARN] layout.tsx not found at $LayoutPath – skipping import fix." -ForegroundColor Yellow
        return
    }

    Write-Host "[INFO] Checking globals.css import in app/layout.tsx ..." -ForegroundColor White
    $layoutContent = Get-Content $LayoutPath -Raw

    if ($layoutContent -match "globals\.css") {
        Write-Host "  = globals.css already imported in layout.tsx" -ForegroundColor DarkGray
        return
    }

    # Insert import line after 'use client' if present, otherwise at very top.
    $importLine = "import './globals.css';"

    if ($layoutContent -match "'use client'|""use client""") {
        Write-Host "  + Inserting globals.css import after 'use client'..." -ForegroundColor Green
        $updated = $layoutContent -replace "(('use client'|""use client"");?\s*)", "`$1`r`n$importLine`r`n"
    }
    else {
        Write-Host "  + Prepending globals.css import at top of layout.tsx..." -ForegroundColor Green
        $updated = "$importLine`r`n$layoutContent"
    }

    # Backup existing file
    $backupPath = "$LayoutPath.bak-phase136-$timestamp"
    Copy-Item $LayoutPath $backupPath -Force
    Write-Host "  > Backup written to $backupPath" -ForegroundColor DarkYellow

    $updated | Set-Content -Path $LayoutPath -Encoding UTF8
}

function Ensure-TailwindConfig {
    # Support tailwind.config.ts or .js
    $tsConfig = Join-Path $PWD "tailwind.config.ts"
    $jsConfig = Join-Path $PWD "tailwind.config.js"

    $configPath = $null
    if (Test-Path $tsConfig) { $configPath = $tsConfig }
    elseif (Test-Path $jsConfig) { $configPath = $jsConfig }

    if (-not $configPath) {
        Write-Host "[WARN] No tailwind.config.ts/js found – creating a basic config (ts)." -ForegroundColor Yellow
        $configPath = $tsConfig
        @"
import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
export default config;
"@ | Set-Content -Path $configPath -Encoding UTF8

        Write-Host "  > Created $configPath with standard Next.js App Router settings." -ForegroundColor Green
        return
    }

    Write-Host "[INFO] Ensuring Tailwind content paths in $configPath ..." -ForegroundColor White
    $config = Get-Content $configPath -Raw

    $needed = @(
        './app/**/*.{js,ts,jsx,tsx,mdx}',
        './pages/**/*.{js,ts,jsx,tsx,mdx}',
        './components/**/*.{js,ts,jsx,tsx,mdx}',
        './src/**/*.{js,ts,jsx,tsx,mdx}'
    )

    $modified = $false
    foreach ($p in $needed) {
        if ($config -notmatch [Regex]::Escape($p)) {
            Write-Host "  + Adding missing content path: $p" -ForegroundColor Green
            # crude but safe: insert before closing array bracket `]`
            $config = $config -replace "content\s*:\s*\[", "content: [`r`n    `"$p`","
            $modified = $true
        }
    }

    if ($modified) {
        # Backup
        $backup = "$configPath.bak-phase136-$timestamp"
        Copy-Item $configPath $backup -Force
        Write-Host "  > Backup written to $backup" -ForegroundColor DarkYellow

        $config | Set-Content -Path $configPath -Encoding UTF8
    }
    else {
        Write-Host "  = All required content paths already present." -ForegroundColor DarkGray
    }
}

function Ensure-GlobalsCss {
    $globalsPath = Join-Path $PWD "app\globals.css"

    if (Test-Path $globalsPath) {
        Write-Host "[INFO] app/globals.css already exists – keeping but ensuring Tailwind directives." -ForegroundColor White
        $content = Get-Content $globalsPath -Raw
        $changed = $false

        if ($content -notmatch "@tailwind\s+base;") {
            $content = "@tailwind base;`r`n$content"
            $changed = $true
        }
        if ($content -notmatch "@tailwind\s+components;") {
            $content = $content -replace "@tailwind base;`r`n", "@tailwind base;`r`n@tailwind components;`r`n"
            $changed = $true
        }
        if ($content -notmatch "@tailwind\s+utilities;") {
            $content = $content + "`r`n@tailwind utilities;`r`n"
            $changed = $true
        }

        if ($changed) {
            $backup = "$globalsPath.bak-phase136-$timestamp"
            Copy-Item $globalsPath $backup -Force
            Write-Host "  > Backup written to $backup" -ForegroundColor DarkYellow

            $content | Set-Content -Path $globalsPath -Encoding UTF8
            Write-Host "  + Updated globals.css with missing Tailwind directives." -ForegroundColor Green
        }
        else {
            Write-Host "  = Tailwind directives already present in globals.css." -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "[WARN] app/globals.css missing – creating a sane default." -ForegroundColor Yellow
        @"
/* Phase136 default globals for Truvern */

@tailwind base;
@tailwind components;
@tailwind utilities;

html, body {
  min-height: 100%;
}

body {
  @apply bg-slate-950 text-slate-50 antialiased;
}

a {
  @apply text-sky-400 hover:text-sky-300;
}
"@ | Set-Content -Path $globalsPath -Encoding UTF8

        Write-Host "  > Created app/globals.css with Tailwind directives and basic Truvern theme." -ForegroundColor Green
    }
}

function Detect-PackageManager {
    if (Test-Path "pnpm-lock.yaml") { return "pnpm" }
    if (Test-Path "yarn.lock")      { return "yarn" }
    if (Test-Path "package-lock.json") { return "npm" }
    # fallback
    return "npm"
}

# endregion --------------------------------------------------------------------


# region: Step 1 – Ensure Tailwind + globals.css wiring -----------------------

Write-Section "Step 1 – Ensure Tailwind config & globals.css"

Ensure-TailwindConfig
Ensure-GlobalsCss

$layoutPath = Join-Path $PWD "app\layout.tsx"
Ensure-ImportGlobalsCss -LayoutPath $layoutPath

# endregion --------------------------------------------------------------------


# region: Step 2 – Clean .next cache -----------------------------------------

Write-Section "Step 2 – Clean .next build cache"

if (Test-Path ".next") {
    Write-Host "[INFO] Removing .next directory for a clean rebuild..." -ForegroundColor White
    try {
        Remove-Item ".next" -Recurse -Force -ErrorAction Stop
        Write-Host "  > .next removed." -ForegroundColor Green
    }
    catch {
        Write-Host "[WARN] Failed to fully remove .next (some files may be locked). Continuing..." -ForegroundColor Yellow
    }
}
else {
    Write-Host "  = .next folder does not exist – nothing to clean." -ForegroundColor DarkGray
}

# endregion --------------------------------------------------------------------


# region: Step 3 – Install deps (if needed) -----------------------------------

Write-Section "Step 3 – Verify dependencies"

$pkgMgr = Detect-PackageManager
Write-Host "[INFO] Detected package manager: $pkgMgr" -ForegroundColor White

$needInstall = $false
if (-not (Test-Path "node_modules")) {
    $needInstall = $true
    Write-Host "  ! node_modules missing – will run a fresh install." -ForegroundColor Yellow
}

if ($needInstall) {
    if ($pkgMgr -eq "pnpm") {
        pnpm install
    }
    elseif ($pkgMgr -eq "yarn") {
        yarn install
    }
    else {
        npm install
    }
}
else {
    Write-Host "  = node_modules present – skipping full install (faster)." -ForegroundColor DarkGray
}

# endregion --------------------------------------------------------------------


# region: Step 4 – Local build (Next.js) --------------------------------------

Write-Section "Step 4 – Run Next.js build (fresh CSS pipeline)"

try {
    if ($pkgMgr -eq "pnpm") {
        pnpm run build
    }
    elseif ($pkgMgr -eq "yarn") {
        yarn build
    }
    else {
        npm run build
    }
    Write-Host "`n[OK] Local build completed successfully." -ForegroundColor Green
}
catch {
    Write-Host "`n[ERROR] Build failed – check the log above and $logFile for details." -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# endregion --------------------------------------------------------------------


# region: Step 5 – Deploy prebuilt to Vercel ----------------------------------

Write-Section "Step 5 – Deploy prebuilt .next to Vercel (prod)"

if (-not (Get-Command "vercel" -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] 'vercel' CLI not found in PATH. Install it with:  npm i -g vercel" -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# Prefer deploy using prebuilt .next for speed & consistency
try {
    Write-Host "[INFO] Deploying with: vercel deploy --prebuilt --prod --confirm" -ForegroundColor White
    vercel deploy --prebuilt --prod --confirm | Tee-Object -Variable vercelOutput | Out-Host

    # Try to capture the final deployment URL from Vercel output
    $deploymentUrl = ($vercelOutput | Select-String -Pattern "https://.*\.vercel\.app" -AllMatches).Matches |
        Select-Object -Last 1 -ExpandProperty Value

    if ($deploymentUrl) {
        Write-Host "`n[INFO] Detected deployment URL: $deploymentUrl" -ForegroundColor Green
    }
    else {
        Write-Host "`n[WARN] Could not automatically detect deployment URL from Vercel output." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "`n[ERROR] Vercel deploy failed – review the log above and $logFile." -ForegroundColor Red
    Stop-Transcript | Out-Null
    exit 1
}

# endregion --------------------------------------------------------------------


# region: Step 6 – Basic CSS health check on live URLs ------------------------

Write-Section "Step 6 – Live health check (HTTP 200 for key routes)"

# Prefer custom PROD_DOMAIN if set; otherwise default to truvern.com
$baseUrl = $env:PROD_DOMAIN
if (-not $baseUrl -or $baseUrl.Trim() -eq "") {
    $baseUrl = "https://truvern.com"
}

$routes = @(
    "/",
    "/trust-network",
    "/vendors",
    "/reports/board"
)

foreach ($r in $routes) {
    $url = "$baseUrl$r".Replace("//trust-network","/trust-network")  # avoid double slash for root
    Write-Host "Checking $url ..." -ForegroundColor White
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 30
        if ($resp.StatusCode -eq 200) {
            Write-Host "  [200 OK] $url" -ForegroundColor Green
        }
        else {
            Write-Host "  [WARN] $url returned HTTP $($resp.StatusCode)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  [ERROR] Failed to reach $url – $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nNOTE: To visually confirm CSS, open one of the URLs above in a browser." -ForegroundColor Cyan
Write-Host "      The pages should now be fully styled with Tailwind (no bare HTML)." -ForegroundColor Cyan

# endregion --------------------------------------------------------------------


# region: Wrap up --------------------------------------------------------------

Write-Section "Phase136 completed"

Write-Host "Log file saved to: $logFile" -ForegroundColor DarkYellow
Write-Host "If something still looks wrong, send me a screenshot of the browser view AND the tail end of this log." -ForegroundColor White

Stop-Transcript | Out-Null

# endregion --------------------------------------------------------------------
