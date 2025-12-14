param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$logsDir  = Join-Path $repoRoot "logs"

if (!(Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$report = Join-Path $logsDir "Phase192-$timestamp.txt"

function Log($msg) {
    Add-Content -Path $report -Value $msg
    Write-Host $msg -ForegroundColor Cyan
}

Log "=== Phase192: Final Production Deploy ==="
Log "Started: $(Get-Date)"
Log ""

# ---------------------------
# 1) BUILD
# ---------------------------
Log "## Running npm build..."

$oldEAP = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    Push-Location $repoRoot

    # Critical: run through cmd to avoid NativeCommandError
    $buildOut = & cmd /c "npm run build" 2>&1 | Out-String

    Add-Content -Path $report -Value "---- Build Output ----"
    Add-Content -Path $report -Value $buildOut
    Add-Content -Path $report -Value "-----------------------"

    if ($LASTEXITCODE -ne 0) {
        Log "BUILD FAILED"
        exit 1
    }

    Log "Build succeeded."
}
finally {
    Pop-Location
    $ErrorActionPreference = $oldEAP
}

# ---------------------------
# 2) DEPLOY
# ---------------------------
# ---------------------------
# 2) DEPLOY (Safe Wrapper)
# ---------------------------
Log ""
Log "## Deploying to Vercel Production..."

$oldEAP = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"

    # Run through cmd to avoid NativeCommandError
    $deployOut = & cmd /c "npx vercel --prod --confirm" 2>&1 | Out-String

    Add-Content -Path $report -Value "---- Deploy Output ----"
    Add-Content -Path $report -Value $deployOut
    Add-Content -Path $report -Value "------------------------"

    if ($LASTEXITCODE -ne 0) {
        Log "DEPLOY FAILED (exit code: $LASTEXITCODE)"
        exit 1
    }

    Log "Deploy SUCCEEDED"
}
finally {
    $ErrorActionPreference = $oldEAP
}

# ---------------------------
# 3) HEALTH CHECKS
# ---------------------------
Log ""
Log "## Running health checks..."

$urls = @(
    "https://truvern.com",
    "https://truvern.com/trust-network",
    "https://truvern.com/vendors",
    "https://truvern.com/reports/board",
    "https://truvern.com/api/vendors",
    "https://truvern.com/api/evidence/list"
)

foreach ($u in $urls) {
    try {
        $r = Invoke-WebRequest -Uri $u -TimeoutSec 10
        Log "$u : $($r.StatusCode)"
    }
    catch {
        Log "$u : FAILED - $($_.Exception.Message)"
    }
}

Log ""
Log "=== Phase192 Complete ==="
Log "Report saved to: $report"

Write-Host "`n===== Phase192 COMPLETE =====`n" -ForegroundColor Yellow
