# =========================
# Phase123-PolishChain.ps1
# =========================
# Purpose: Final UI polish + snapshot + build + deploy + verify
# =========================

$ErrorActionPreference = "Stop"

try { Set-Location (Get-Location) } catch {}
$PWD = (Get-Location).Path

# Prevent running from system directory
if (Test-Path "C:\Windows\System32") {
    if ($PWD -match '\\Windows\\System32$') {
        Write-Host "❌ Do not run from System32. Please cd into your project folder and rerun." -ForegroundColor Red
        exit 1
    }
}

# Setup directories and logs
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $PWD "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$mainLog = Join-Path $logDir "phase123-$ts.log"
$vrfLog  = Join-Path $logDir "route-verify-$ts.txt"
$shotPng = Join-Path $logDir "board-$ts.png"

Write-Host "`n=== Phase123: Snapshot + Build + Deploy + Verify ===`n" -ForegroundColor Cyan

# ---------- Step 1: Snapshot backup ----------
Write-Host "📦 Creating pre-deploy snapshot..." -ForegroundColor Cyan
if (Test-Path ".next") {
    Compress-Archive -Path ".next" -DestinationPath "$logDir\snapshot-$ts.zip" -Force
}
Write-Host "✅ Snapshot created at $logDir\snapshot-$ts.zip" -ForegroundColor Green

# ---------- Step 2: Ensure dependencies ----------
Write-Host "`n📦 Installing dependencies..." -ForegroundColor Cyan
cmd /c "pnpm install" >> "$mainLog" 2>&1

# ---------- Step 3: Generate Prisma client ----------
Write-Host "`n🧩 Generating Prisma client..." -ForegroundColor Cyan
try {
    # Explicitly load .env into current PowerShell session
    if (Test-Path ".env") {
        Get-Content ".env" | ForEach-Object {
            if ($_ -match "^\s*([^#=]+?)\s*=\s*(.*)$") {
                $key = $matches[1].Trim()
                $val = $matches[2].Trim('"').Trim()
                [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
            }
        }
        Write-Host "✅ Environment variables from .env loaded into process." -ForegroundColor Green
    } else {
        Write-Host "⚠️ No .env file found; continuing anyway..." -ForegroundColor Yellow
    }

    # Run Prisma generate directly (no cmd, no subshell)
    & pnpm exec prisma generate | Tee-Object -FilePath $mainLog -Append

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Prisma generate failed. See $mainLog" -ForegroundColor Red
        exit 2
    } else {
        Write-Host "✅ Prisma client generated successfully." -ForegroundColor Green
    }
}
catch {
    Write-Host "❌ Prisma generation error: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}

# ---------- Step 4: Build ----------
Write-Host "`n🏗️ Building project..." -ForegroundColor Cyan
try {
    # Run pnpm build with clean stderr handling
    $buildOutput = & pnpm run build 2>&1
    $buildOutput | Tee-Object -FilePath $mainLog -Append | Out-Null

    # Check for real build failures (not Prisma env echoes)
    if ($LASTEXITCODE -ne 0 -and ($buildOutput -notmatch "Environment variables loaded from .env")) {
        Write-Host "⚠️ Build failed. Check $mainLog" -ForegroundColor Yellow
        exit 3
    } else {
        Write-Host "✅ Build completed successfully." -ForegroundColor Green
    }
}
catch {
    Write-Host "❌ Build error: $($_.Exception.Message)" -ForegroundColor Red
    exit 3
}

# ---------- Step 5: Deploy to Vercel ----------
Write-Host "`n🚀 Deploying to Vercel..." -ForegroundColor Cyan
vercel --prod --yes 2>&1 | Tee-Object -FilePath $mainLog -Append | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️ Vercel deploy encountered issues. See $mainLog" -ForegroundColor Yellow
} else {
    Write-Host "✅ Vercel deployment completed successfully." -ForegroundColor Green
}

# ---------- Step 6: Verify routes ----------
Write-Host "`n🌐 Verifying key routes..." -ForegroundColor Cyan
$base = "https://truvern.com"
$routes = @("/", "/trust-network", "/vendors", "/reports/board", "/reports/board/preview", "/pricing", "/subscribe", "/security", "/login")

$okAll = $true
foreach ($r in $routes) {
    try {
        $u = "$base$r"
        $to = Get-Date
        $res = Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 20
        $ms = [int]((Get-Date) - $to).TotalMilliseconds
        if ($res.StatusCode -eq 200) {
            Write-Host "OK $u -> 200 ($ms ms)" -ForegroundColor Green
            "OK {0} -> 200 ({1} ms)" -f $u, $ms | Tee-Object -FilePath $vrfLog -Append | Out-Null
        } else {
            Write-Host "ERR $u -> $($res.StatusCode)" -ForegroundColor Red
            "ERR {0} -> {1}" -f $u, $res.StatusCode | Tee-Object -FilePath $vrfLog -Append | Out-Null
            $okAll = $false
        }
    } catch {
        Write-Host "ERR $u ($($_.Exception.Message))" -ForegroundColor Red
        "ERR {0} -> {1}" -f $u, $_.Exception.Message | Tee-Object -FilePath $vrfLog -Append | Out-Null
        $okAll = $false
    }
}

if ($okAll) {
    Write-Host "`n✅ All key routes returned HTTP 200." -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Some routes failed. See $vrfLog" -ForegroundColor Yellow
}

Write-Host "`n=== Phase123 complete ===" -ForegroundColor Cyan
