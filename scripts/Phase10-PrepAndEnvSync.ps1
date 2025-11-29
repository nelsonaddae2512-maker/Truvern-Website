param(
  [string]$Root = "C:\Users\MR.NELSON\Downloads\truvern",
  [int]$PullTimeoutSec = 90
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$PSNativeCommandUseErrorActionPreference = $true

function Log([string]$msg,[string]$color="Gray"){
  $ts = Get-Date -Format "HH:mm:ss"
  $line = "[$ts] $msg"
  $line | Out-File -FilePath $script:LogPath -Append -Encoding UTF8
  Write-Host $line -ForegroundColor $color
}

# ==== Prep ====
Set-Location $Root
Write-Host "== Phase10 Prep ==" -ForegroundColor Cyan
Write-Host ("PWD: " + $PWD) -ForegroundColor Yellow

# Non-interactive for CLIs
$env:CI = "1"
$env:FORCE_COLOR = "0"

# Kill any stragglers
Get-Process node,npm,vercel -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Log folder
$logDir = Join-Path $Root "logs\phase10"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$script:LogPath = Join-Path $logDir "prep+envsync.log"
"`n=== New run @ $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===`n" | Out-File -FilePath $LogPath -Append -Encoding UTF8

Log ".vercel\project.json exists: $([IO.File]::Exists((Join-Path $Root '.vercel\project.json'))))"
if (-not $env:VERCEL_TOKEN) { Log "Missing VERCEL_TOKEN" "Red" } else { Log "VERCEL_TOKEN found (masked)" "Green" }

# ==== EnvSync-Lite ====
Log "== EnvSync-Lite start ==" "Cyan"

# Guard: linked project required
if (-not (Test-Path (Join-Path $Root ".vercel\project.json"))) {
  Log "❌ .vercel\project.json missing. Run 'vercel link' (interactive) first, then rerun this script." "Red"
  Write-Host "`nHint:" -ForegroundColor DarkYellow
  Write-Host "  vercel link --project truvern --token YOUR_VERCEL_TOKEN" -ForegroundColor DarkYellow
  exit 2
}

# Try vercel pull with a hard timeout
$pulled = Join-Path $Root ".vercel\.env.production.local"
if (-not (Test-Path $pulled)) {
  Log "Running: vercel pull --environment=production --yes (timeout: ${PullTimeoutSec}s)" "Yellow"
  $job = Start-Job { vercel pull --environment=production --yes --token $env:VERCEL_TOKEN }
  if (-not (Wait-Job $job -Timeout $PullTimeoutSec)) {
    Stop-Job $job -ErrorAction SilentlyContinue
    Receive-Job $job | Out-Null
    Log "vercel pull timed out after $PullTimeoutSec s — continuing with whatever is present." "Red"
  } else {
    $out = Receive-Job $job | Out-String
    Log "vercel pull completed.`n$out" "DarkGray"
  }
} else {
  Log "Vercel env file already present."
}

function Read-DotEnv($path){
  $map = [ordered]@{}
  if (-not (Test-Path $path)) { return $map }
  foreach ($line in Get-Content $path) {
    $t = $line.Trim(); if ($t -eq "" -or $t.StartsWith("#")) { continue }
    $eq = $t.IndexOf("="); if ($eq -lt 1) { continue }
    $k = $t.Substring(0,$eq).Trim()
    $v = $t.Substring($eq+1).Trim()
    if ($v -match "^(\"|')(.*)(\1)$") { $v = $Matches[2] }
    $map[$k] = $v
  }
  $map
}

$vercel = Read-DotEnv $pulled
$localP = Read-DotEnv (Join-Path $Root ".env.production.local")
$localL = Read-DotEnv (Join-Path $Root ".env.local")
$localB = Read-DotEnv (Join-Path $Root ".env")

$local = [ordered]@{}
foreach ($k in $localB.Keys) { $local[$k] = $localB[$k] }
foreach ($k in $localL.Keys) { $local[$k] = $localL[$k] }
foreach ($k in $localP.Keys) { $local[$k] = $localP[$k] }

$missLocal=@(); $missVercel=@(); $diff=@()
$keys = New-Object System.Collections.Generic.HashSet[string]
$null = $keys.UnionWith($vercel.Keys)
$null = $keys.UnionWith($local.Keys)

foreach ($k in $keys) {
  $inV = $vercel.Contains($k); $inL = $local.Contains($k)
  if ($inV -and -not $inL) { $missLocal += $k; continue }
  if ($inL -and -not $inV) { $missVercel += $k; continue }
  if ($inV -and $inL) {
    if ( ($vercel[$k] ?? "") -ne ($local[$k] ?? "") ) { $diff += $k }
  }
}

# Health checks with strict timeouts
function Test-Url($u){
  for ($i=1; $i -le 3; $i++) {
    try {
      $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Uri $u
      if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 400) { return $true }
    } catch { Start-Sleep -Seconds 1 }
  }
  return $false
}
$health = @("https://truvern.com/ops/health","https://truvern.com/api/health")
$healthStatus = @{}
foreach ($u in $health) { $healthStatus[$u] = (Test-Url $u) }

# Report
$report = Join-Path $logDir "envsync-bundled-report.txt"
$summary = @()
$summary += "=== Phase10 Prep + EnvSync-Lite Report ==="
$summary += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$summary += "Project: $Root"
$summary += ""
$summary += "Missing in LOCAL : " + (($missLocal  -join ', ')  ?: '<none>')
$summary += "Missing in VERCEL: " + (($missVercel -join ', ')  ?: '<none>')
$summary += "Different values : " + (($diff       -join ', ')  ?: '<none>')
$summary += ""
$summary += "Health:"
foreach ($u in $health) { $summary += " - $u : " + ($(if ($healthStatus[$u]) {'OK'} else {'FAIL'})) }
$summary += ""
$summary += "Log: $script:LogPath"
$summary -join "`r`n" | Out-File -FilePath $report -Encoding UTF8 -Force

Write-Host "`n=== EnvSync Summary ===" -ForegroundColor Cyan
Write-Host "Report: $report" -ForegroundColor Yellow
if ($missLocal.Count -gt 0)  { Write-Host "• Missing in LOCAL : $($missLocal -join ', ')" -ForegroundColor Red }
if ($missVercel.Count -gt 0) { Write-Host "• Missing in VERCEL: $($missVercel -join ', ')" -ForegroundColor Red }
if ($diff.Count -gt 0)       { Write-Host "• Different values : $($diff -join ', ')" -ForegroundColor DarkYellow }
if ($missLocal.Count -eq 0 -and $missVercel.Count -eq 0 -and $diff.Count -eq 0) {
  Write-Host "• Local and Vercel env match." -ForegroundColor Green
}
Write-Host "• Health /ops/health : " + ($(if ($healthStatus[$health[0]]) {"OK"} else {"FAIL"}))
Write-Host "• Health /api/health : " + ($(if ($healthStatus[$health[1]]) {"OK"} else {"FAIL"}))
Log "Done." "Cyan"
