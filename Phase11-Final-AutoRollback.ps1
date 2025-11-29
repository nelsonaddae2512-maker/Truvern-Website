# --- Phase 11 Final: Auto-Rollback + Daily Board Report ---
$ErrorActionPreference = "Stop"
$root = "C:\Users\MR.NELSON\Downloads\truvern"
$logDir = Join-Path $root "logs\phase11"
if (-not (Test-Path $logDir)) { New-Item -Type Directory -Force -Path $logDir | Out-Null }

function Log($msg,[string]$color="Gray") {
  $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
  Write-Host $line -ForegroundColor $color
}

function Test-Url([string]$u){
  try {
    $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Uri $u
    return ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400)
  } catch { return $false }
}

# --- Phase start ---
Log "=== Phase 11 Final Rollback & Board Report ===" "Cyan"

# 1️⃣  Health checks
$opsOk = Test-Url "https://truvern.com/ops/health"
$apiOk = Test-Url "https://truvern.com/api/health"
Log "ops/health → $opsOk"
Log "api/health → $apiOk"

# 2️⃣  Generate board report
$repDir = Join-Path $root "reports\board"
if (-not (Test-Path $repDir)) { New-Item -Type Directory -Force -Path $repDir | Out-Null }
$repFile = Join-Path $repDir ("board-" + (Get-Date -Format "yyyy-MM-dd") + ".txt")
@(
  "=== Truvern Daily Board Report ==="
  "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  "ops/health: $(if($opsOk){'OK'}else{'FAIL'})"
  "api/health: $(if($apiOk){'OK'}else{'FAIL'})"
  ""
  "Auto-Rollback: $(if(-not($opsOk -and $apiOk)){'Triggered'}else{'Not needed'})"
) | Out-File $repFile -Encoding UTF8 -Force
Log "Board report saved: $repFile" "Green"

# 3️⃣  Conditional rollback
if (-not ($opsOk -and $apiOk)) {
  Log "⚠️  One or more checks failed – initiating rollback..." "Yellow"
  try {
    npx vercel rollback --token $env:VERCEL_TOKEN | Out-Null
    Log "Rollback executed successfully." "Green"
  } catch {
    Log "Rollback failed: $($_.Exception.Message)" "Red"
  }
} else {
  Log "✅ All systems healthy – no rollback required." "Green"
}

# 4️⃣  Scheduler setup (runs daily at 7 AM)
$taskName = "Truvern-Phase11-DailyReport"
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false | Out-Null
}
$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$psArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$root\Phase11-Final-AutoRollback.ps1`""
$action = New-ScheduledTaskAction -Execute $psExe -Argument $psArgs
$trigger = New-ScheduledTaskTrigger -Daily -At "07:00"
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal `
  -Description "Truvern daily auto-health report and rollback" | Out-Null
Log "Scheduled daily run created: $taskName (07:00)" "Cyan"

Log "Phase 11 Final complete." "Green"
