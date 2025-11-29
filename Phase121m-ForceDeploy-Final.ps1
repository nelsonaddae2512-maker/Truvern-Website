# ==============================
# Phase121m-ForceDeploy-Final.ps1
# Clean, resilient deploy for Truvern Production
# ==============================
# --- Force correct working directory ---
$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
if ((Get-Location).Path -ne $projectPath) {
    Write-Host "`nSwitching to correct project directory..."
    Set-Location $projectPath
}
Write-Host "Current directory: $((Get-Location).Path)"
Write-Host "Checking for package.json..."
if (-not (Test-Path "$projectPath\package.json")) {
    Write-Host "❌ ERROR: package.json not found in $projectPath"
    pause
    exit 1
}

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Config ---
$TEAM     = 'nelson-addaes-projects'
$PROJECT  = 'truvern'
$DOMAIN   = 'truvern.com'
$UsePrebuilt = $true

# --- Always run from the script folder ---
try {
    if ($PSScriptRoot) { Set-Location $PSScriptRoot }
} catch {}

# --- Logging ---
New-Item -ItemType Directory -Force -Path '.\logs' | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$LOG   = ".\logs\phase121m-forcedeploy-$stamp.log"
function Log($m){ $m | Tee-Object -FilePath $LOG -Append }

Log "=== Phase121m ForceDeploy @ $stamp ==="
Log "Team: $TEAM | Project: $PROJECT | Domain: $DOMAIN"

# --- Verify Vercel CLI ---
try {
    $vcVer = vercel --version
    Log "Vercel CLI: $vcVer"
} catch {
    Log "ERROR: Vercel CLI not found. Run 'npm i -g vercel' or 'pnpm dlx vercel'."
    Read-Host "Press Enter to close"
    exit 1
}

# --- Whoami / Auth ---
try {
    $who = vercel whoami
    Log "Authenticated as: $who"
} catch {
    Log "WARN: Not logged in or scope missing. Run 'vercel login'."
}

# --- Ensure correct project link ---
if (Test-Path .\.vercel) {
    $meta = Get-Content .\.vercel\project.json -ErrorAction SilentlyContinue | Out-String
    if ($meta -and ($meta -match '"orgId"') -and ($meta -match 'nelson-ai-projects')) {
        Log "Stale .vercel link found. Re-linking..."
        Remove-Item -Recurse -Force .\.vercel
    }
}

if (-not (Test-Path .\.vercel)) {
    Log "Linking folder to $TEAM/$PROJECT..."
    try {
        vercel link --yes --project $PROJECT --scope $TEAM | ForEach-Object { Log $_ }
    } catch {
        Log "WARN: direct link failed. Trying interactive link."
        vercel link --scope $TEAM | ForEach-Object { Log $_ }
    }
}

# --- Pull environment ---
try {
    Log "Pulling production env..."
    vercel pull --yes --environment=production --scope $TEAM | ForEach-Object { Log $_ }
} catch {
    Log "WARN: vercel pull failed. Continuing anyway: $($_.Exception.Message)"
}

# --- Safe RunStep helper ---
function RunStep($cmd) {
    Log "`n$cmd"
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = "cmd.exe"
    $processInfo.Arguments = "/c $cmd"
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    ($stdout + "`n" + $stderr) | Tee-Object -FilePath $LOG -Append | Out-Host

    if ($process.ExitCode -ne 0) {
        throw "Command failed ($($process.ExitCode)): $cmd"
    }
}

# --- Dependency Install & Build ---
$havePnpm = (Get-Command pnpm -ErrorAction SilentlyContinue) -ne $null

# --- Safe PNPM Install ---
$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Write-Host "`nRunning PNPM install from: $projectPath"
if (Test-Path "$projectPath\package.json") {
    Push-Location $projectPath
    try {
        pnpm install --frozen-lockfile
    } catch {
        Write-Host "⚠️ Frozen install failed, retrying without frozen flag..."
        pnpm install --no-frozen-lockfile
    } finally {
        Pop-Location
    }
} else {
    Write-Host "❌ ERROR: package.json missing at $projectPath"
    pause
    exit 1
}

# --- Deploy to Production ---
$deployCmd = if ($UsePrebuilt) {
    "vercel deploy --prod --confirm --prebuilt --scope $TEAM"
} else {
    "vercel deploy --prod --confirm --scope $TEAM"
}
# --- Safe Deploy Execution ---
Write-Host "`nDeploying to Production..."
try {
    $deployCmd = "vercel deploy --prod --yes --scope nelson-addaes-projects --confirm"
    Write-Host "Running: $deployCmd"
    $deployOutput = & vercel deploy --prod --yes --scope nelson-addaes-projects --confirm 2>&1 | Tee-Object -FilePath $LOG -Append
    Write-Host "`n✅ Deployment complete."
} catch {
    Write-Host "`n❌ Deployment failed: $($_.Exception.Message)"
    $_ | Out-File -Append -FilePath $LOG
    pause
}

# --- Verify Routes ---
$urls = @(
    "https://$DOMAIN/",
    "https://$DOMAIN/trust-network",
    "https://$DOMAIN/vendors",
    "https://$DOMAIN/reports/board"
)

Log "`n-- HTTP 200 verification --"
$all200 = $true
foreach ($u in $urls) {
    try {
        $r = Invoke-WebRequest -Uri $u -Method GET -MaximumRedirection 5 -TimeoutSec 30
        Log ("{0} -> {1}" -f $u, $r.StatusCode)
        if ($r.StatusCode -ne 200) { $all200 = $false }
    } catch {
        Log ("{0} -> FAIL: {1}" -f $u, $_.Exception.Message)
        $all200 = $false
    }
}

# --- Recent Deployments Audit ---
Log "`n-- Recent deployments for $PROJECT (scope: $TEAM) --"
try { vercel ls $PROJECT --scope $TEAM | ForEach-Object { Log $_ } } catch { Log "WARN: vercel ls failed: $($_.Exception.Message)" }

# --- Summary ---
Log "`n=== Summary ==="
if (-not $deploymentUrl) { $deploymentUrl = "(unknown)" }
Log ("Deployment URL: {0}" -f $deploymentUrl)
if ($all200) { Log "All key routes HTTP 200: YES" } else { Log "All key routes HTTP 200: NO" }
Log ("Log saved: {0}" -f $LOG)

Write-Host "`nDone. Full log: $LOG"
Read-Host "Press Enter to close"
