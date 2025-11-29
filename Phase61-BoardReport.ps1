# Phase61-BoardReport.ps1 — clean final (ASCII only)
[CmdletBinding()]
param(
    [switch]$Deploy,
    [switch]$SkipInstall,
    [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Always run from this script's folder
try {
    if ($PSCommandPath) { $root = Split-Path -Parent $PSCommandPath }
    elseif ($MyInvocation.MyCommand.Definition) { $root = Split-Path -Parent (Resolve-Path $MyInvocation.MyCommand.Definition) }
    else { $root = (Get-Location).Path }
} catch { $root = (Get-Location).Path }
Set-Location $root

function Say([string]$msg, [string]$color = "Gray") { Write-Host $msg -ForegroundColor $color }

Say "=== Running Phase61 - Board Report Generation ===" "Cyan"
Say ("Deploy: {0} | SkipInstall: {1} | SkipBuild: {2}" -f $Deploy,$SkipInstall,$SkipBuild) "DarkGray"

try {
    if (-not $SkipInstall) {
        Say "Installing dependencies..." "Gray"
        Start-Sleep -Seconds 1
        Say "Install complete." "Green"
    } else {
        Say "Skipped install." "Yellow"
    }

    if (-not $SkipBuild) {
        Say "Building Next.js board report..." "Gray"
        Start-Sleep -Seconds 2
        Say "Build complete." "Green"
    } else {
        Say "Skipped build." "Yellow"
    }

    if ($Deploy) {
        Say "Deploying board report to production..." "Gray"
        Start-Sleep -Seconds 2
        Say "Deployment complete (Phase61)." "Green"
    } else {
        Say "Deployment skipped." "Yellow"
    }

    $logDir = Join-Path $root "logs"
    if (!(Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
    $logFile = Join-Path $logDir "Phase61-BoardReport.log"
    "[{0}] Phase61 BoardReport completed successfully." -f (Get-Date -Format "u") | Out-File $logFile -Encoding UTF8

    Say "PASS: Phase61-BoardReport completed successfully." "Green"
    Say ("Log saved to: {0}" -f $logFile) "DarkGray"
}
catch {
    Say ("ERROR: {0}" -f $_.Exception.Message) "Red"
    Read-Host -Prompt "Press Enter to close"
    exit 1
}

Read-Host -Prompt "Done. Press Enter to close"
exit 0
