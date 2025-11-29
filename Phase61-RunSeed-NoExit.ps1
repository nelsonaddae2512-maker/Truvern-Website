param(
  [switch]$WithAssessment,
  [switch]$WithRemediation,
  [switch]$Deploy
)

# Always run from this script’s folder
$root = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $root

function Say($m,$c="Gray"){ Write-Host $m -ForegroundColor $c }

# Ensure logs folder
$logs = Join-Path $root "logs"
if (-not (Test-Path -LiteralPath $logs)) { New-Item -ItemType Directory -Path $logs | Out-Null }
$stamp  = Get-Date -Format "yyyyMMdd-HHmmss"
$log    = Join-Path $logs ("Phase61-Harness-" + $stamp + ".log")

# Start transcript safely
$didTranscript = $false
try { Start-Transcript -Path $log -Append | Out-Null ; $didTranscript = $true } catch {}

function Run($file, [string[]]$args=@()){
  $path = Join-Path $root $file
  if (-not (Test-Path -LiteralPath $path)) { Say "Missing $file" "DarkYellow"; return $false }
  Say "→ Running $file ..." "Cyan"
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $path @args
    Say "✓ Completed $file" "Green"
    return $true
  } catch {
    Say ("✗ ERROR in {0}: {1}" -f $file, $_.Exception.Message) "Red"
    return $false
  }
}

Say "=== Phase61 Harness (BoardReport → FixBoardReport → SeedDemoOrg) ===" "Cyan"

# Build args from switches (these scripts accept literal switches, no values needed)
$seedArgs = @()
if($WithAssessment){ $seedArgs += "-WithAssessment" }
if($WithRemediation){ $seedArgs += "-WithRemediation" }
if($Deploy){ $seedArgs += "-Deploy" }

# 61 -> 61a -> 61b
$ok  = Run "Phase61-BoardReport.ps1"
$ok2 = Run "Phase61a-FixBoardReport.ps1"
$ok3 = Run "Phase61b-SeedDemoOrg.ps1" $seedArgs

# Summarize
if($ok -and $ok2 -and $ok3){
  Say "All harness phases executed successfully." "Green"
}else{
  Say "One or more phases failed or were skipped. See log: $log" "Yellow"
}

# Show OrgId helper if present
$lastId = Join-Path $root ".last-org-id.txt"
if(Test-Path -LiteralPath $lastId){
  $org = (Get-Content $lastId -ErrorAction SilentlyContinue).Trim()
  if($org){
    Say ("OrgId: {0}" -f $org) "Cyan"
    Say ("Open: https://truvern.com/reports/board?org={0}&format=html" -f $org) "DarkGray"
    Say ("API : https://truvern.com/api/reports/board?org={0}" -f $org) "DarkGray"
  }
}

if($didTranscript){ try { Stop-Transcript | Out-Null } catch {} }
Say ""
Read-Host "Done. Press Enter to close"
