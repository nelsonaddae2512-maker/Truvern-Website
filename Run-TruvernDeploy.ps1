# ===========================================
# Run-TruvernDeploy.ps1
# Safe launcher for Truvern deployment
# Forces correct directory before build
# ===========================================

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

Write-Host "`n=== Truvern Safe Deployment Launcher ==="
Write-Host "Running from: $((Get-Location).Path)"

if (-not (Test-Path "$projectPath\package.json")) {
    Write-Host "`n❌ ERROR: package.json not found in project folder!"
    pause
    exit 1
}

$deployScript = Join-Path $projectPath "Phase121m-ForceDeploy-Final.ps1"
if (-not (Test-Path $deployScript)) {
    Write-Host "`n❌ ERROR: ForceDeploy script not found at:`n$deployScript"
    pause
    exit 1
}

# Run the deploy script safely
Write-Host "`nLaunching ForceDeploy script..."
Unblock-File $deployScript
& $deployScript
