# ==========================================
# Phase121n-SafeForceDeploy.ps1
# Ensures deployment runs from correct folder
# ==========================================

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath
Write-Host "`n=== Truvern Safe Force Deploy ==="
Write-Host "Running from: $((Get-Location).Path)`n"

# Verify package.json exists
if (-not (Test-Path "$projectPath\package.json")) {
    Write-Host "❌ ERROR: package.json not found in $projectPath"
    pause
    exit 1
}

# Verify the ForceDeploy script exists
$deployScript = Join-Path $projectPath "Phase121m-ForceDeploy-Final.ps1"
if (-not (Test-Path $deployScript)) {
    Write-Host "❌ ERROR: ForceDeploy script not found at:`n$deployScript"
    pause
    exit 1
}

# Optional: show confirmation
Write-Host "✅ Found deployment script. Launching safely..."
Start-Sleep -Seconds 1

# Run the deploy script
Unblock-File $deployScript
& $deployScript
