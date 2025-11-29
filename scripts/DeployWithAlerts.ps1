param(
  [switch]$Prod = $true,       # --prod by default
  [switch]$NoHealth,           # skip post-deploy health check
  [string]$BaseUrl = "https://truvern.com"
)
$ErrorActionPreference="Continue"
$host.UI.RawUI.WindowTitle = "Truvern: DeployWithAlerts"

# Paths & utilities
$root  = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $root) { $root = (Resolve-Path ".").Path }
Set-Location $root
$notify = Join-Path $root "scripts\Notify.ps1"
$health = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "PostDeployHealth.ps1"
$logDir = Join-Path $root "logs\deploys"
$ts     = Get-Date -Format "yyyyMMdd-HHmmss"
$log    = Join-Path $logDir "deploy-$ts.log"
$audit  = Join-Path $logDir "audit-$ts.json"

# Start transcript to capture every line
Start-Transcript -Path $log -Force | Out-Null

Write-Host "`n== Truvern Deploy + Alerts ==" -ForegroundColor Cyan
# Quick checks
if (-not $env:VERCEL_TOKEN) { Write-Host "Missing VERCEL_TOKEN env var." -ForegroundColor Red; Stop-Transcript | Out-Null; exit 2 }
if (-not (Test-Path "..\\.vercel\\project.json")) {
  Write-Host "..\\.vercel\\project.json not found. Run 'vercel link' once if this fails." -ForegroundColor DarkYellow
}

# Git info (best-effort)
$commit = ""; $branch = ""
try { $commit = (git rev-parse --short HEAD 2>$null) } catch {}
try { $branch = (git rev-parse --abbrev-ref HEAD 2>$null) } catch {}

# Deploy
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$cmdArgs = @("vercel"); if ($Prod){ $cmdArgs += "--prod" }
$cmdArgs += @("--token", $env:VERCEL_TOKEN, "--confirm")
Write-Host "Running: npx $($cmdArgs -join ' ')" -ForegroundColor Yellow
$npxOut = & npx @cmdArgs 2>&1 | Tee-Object -Variable vercelOutput
$exit  = $LASTEXITCODE
$sw.Stop()

# Parse URLs from output
$prodUrl   = ($vercelOutput | Select-String -Pattern "Production:\s*(\S+)" -AllMatches).Matches.Value | ForEach-Object { $_ -replace "Production:\s*","" } | Select-Object -First 1
$inspect   = ($vercelOutput | Select-String -Pattern "Inspect:\s*(\S+)"    -AllMatches).Matches.Value | ForEach-Object { $_ -replace "Inspect:\s*","" }    | Select-Object -First 1

# Post-deploy health
$opsOk=$false; $apiOk=$false; $opsCode=0; $apiCode=0; $opsErr=$null; $apiErr=$null
if (-not $NoHealth) {
  if (Test-Path $health) {
    $h = & powershell -NoProfile -ExecutionPolicy Bypass -File $health -BaseUrl $BaseUrl
    $opsOk  = [bool]$h.ops_ok;  $apiOk  = [bool]$h.api_ok
    $opsCode= $h.ops_code;      $apiCode= $h.api_code
    $opsErr = $h.ops_err;       $apiErr = $h.api_err
  } else {
    Write-Host "Health helper missing: $health" -ForegroundColor DarkYellow
  }
}

# Determine status
$deployOk = ($exit -eq 0)
$healthOk = ($NoHealth -or ($opsOk -and $apiOk))
$overall  = ($deployOk -and $healthOk)

# Build summary text
$lines = @()
$lines += "Truvern Deploy Summary"
$lines += "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$lines += "Branch/Commit: $branch / $commit"
$lines += "Vercel exit: $exit"
$lines += "Prod URL: $prodUrl"
$lines += "Inspect : $inspect"
if (-not $NoHealth) {
  $lines += "ops/health: $opsOk (code=$opsCode) err=$opsErr"
  $lines += "api/health: $apiOk (code=$apiCode) err=$apiErr"
}
$summary = $lines -join "`r`n"
Write-Host "`n$summary`n" -ForegroundColor Gray

# Write audit JSON
$a = [ordered]@{
  time     = (Get-Date).ToString("o")
  duration_ms = $sw.ElapsedMilliseconds
  branch   = $branch
  commit   = $commit
  deploy   = @{
    ok     = $deployOk
    exit   = $exit
    prod   = $prodUrl
    inspect= $inspect
    output = ($vercelOutput -join "`n")
  }
  health   = @{
    checked = (-not $NoHealth)
    ops     = @{ ok=$opsOk; code=$opsCode; err=$opsErr }
    api     = @{ ok=$apiOk; code=$apiCode; err=$apiErr }
  }
  machine  = @{
    user    = $env:USERNAME
    host    = $env:COMPUTERNAME
  }
}
$a | ConvertTo-Json -Depth 6 | Out-File -Encoding UTF8 -Force -FilePath $audit
Write-Host "Audit JSON: $audit" -ForegroundColor Green
Write-Host "Full log  : $log"   -ForegroundColor Green

# Notify (if scripts\Notify.ps1 exists)
if (Test-Path $notify) {
  $failed = -not $overall
  $subject = if ($failed) { "? Deploy Alert: FAILED" } else { "? Deploy OK" }
  $title   = if ($failed) { "Truvern Deploy Failed" } else { "Truvern Deploy Succeeded" }

  # Small HTML with pre
  try { Add-Type -AssemblyName System.Web -ErrorAction SilentlyContinue } catch {}
  $html = "<pre style='font-family:Consolas,Menlo,monospace'>" + $summary.Replace("<","&lt;").Replace(">","&gt;") + "</pre>"

  $res = & powershell -NoProfile -ExecutionPolicy Bypass -File $notify -Subject $subject -TextBody $summary -HtmlBody $html -SlackTitle $title
  Write-Host ("Notify results: slack={0} email={1}" -f $res.slack,$res.email) -ForegroundColor Yellow
} else {
  Write-Host "Notify script missing: scripts\Notify.ps1 (skipped)" -ForegroundColor DarkYellow
}

Stop-Transcript | Out-Null
if ($overall) { exit 0 } else { exit 1 }
