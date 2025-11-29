# =============================
# RunTruvernDeploy.ps1
# Always executes deployment from correct project folder
# =============================

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

Write-Host "`n=== Truvern Deployment Launcher ==="
Write-Host "Running from: $projectPath"
if (-not (Test-Path "$projectPath\package.json")) {
    Write-Host "ERROR: package.json not found in $projectPath"
    pause
    exit 1
}

# Ensure main deploy script exists
$deployScript = Join-Path $projectPath "Phase121m-ForceDeploy-Final.ps1"
if (-not (Test-Path $deployScript)) {
    Write-Host "ERROR: $deployScript not found!"
    pause
    exit 1
}

# Unblock and run
Unblock-File $deployScript
Write-Host "`nLaunching ForceDeploy script..."
& $deployScript
