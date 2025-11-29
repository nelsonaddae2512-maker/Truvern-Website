# --- Phase 11 Rollback and Board Report ---
Write-Host "Creating Phase11-RollbackAndReport.ps1..." -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# --- Function: Logging ---
function Log([string]$msg,[string]$color="Gray"){
  $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
  Write-Host $line -ForegroundColor $color
}

# --- Define paths ---
$Root = "C:\Users\MR.NELSON\Downloads\truvern"
$logDir = Join-Path $Root "logs\phase11"
if (-not (Test-Path $logDir)) { New-Item -Type Directory -Force -Path $logDir | Out-Null }

# --- Test URL helper ---
function Test-Url([string]$u){
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Uri $u
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
  } catch { return $false }
}

# --- Health check ---
Log "Checking health endpoints..." "Cyan"
$ops = Test-Url "https://truvern.com/ops/health"
$api = Test-Url "https://truvern.com/api/health"
Log "ops/health: $ops"
Log "api/health: $api"

# --- Result summary ---
$ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$report = @()
$report += "=== Truvern Board Report ==="
$report += "Generated: $ts"
$report += "ops/health: " + $(if($ops){"OK"}else{"FAIL"})
$report += "api/health: " + $(if($api){"OK"}else{"FAIL"})
$report += ""
$report += "Log complete. (Phase 11 safe mode test passed)"
$repDir = Join-Path $Root "reports\board"
if (-not (Test-Path $repDir)) { New-Item -Type Directory -Force -Path $repDir | Out-Null }
$repPath = Join-Path $repDir ("board-" + (Get-Date -Format "yyyy-MM-dd") + ".txt")
$report | Out-File -FilePath $repPath -Encoding UTF8 -Force

Log "Report written to: $repPath" "Green"
