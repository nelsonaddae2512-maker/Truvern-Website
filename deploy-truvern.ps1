<# =====================================================================
  Truvern: One-Command Build + Deploy (+ optional Alias)
  Save as: deploy-truvern.ps1
  Examples:
    # Personal scope (default) + alias truvern.com
    .\deploy-truvern.ps1 -AliasDomain "truvern.com"

    # Team scope (no alias)
    .\deploy-truvern.ps1 -Team "nelson-addaes-projects"

    # Force relink (cleans .vercel before linking)
    .\deploy-truvern.ps1 -AliasDomain "truvern.com" -ForceRelink

    # Skip build (just alias most recent prod)
    .\deploy-truvern.ps1 -AliasDomain "truvern.com" -SkipBuild
===================================================================== #>

[CmdletBinding()]
param(
  [string]$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern",
  [string]$AliasDomain = "",                  # e.g. "truvern.com" (empty = no alias)
  [string]$Team        = "",                  # e.g. "nelson-addaes-projects" (empty = Personal)
  [switch]$ForceRelink,                       # delete .vercel and link fresh
  [switch]$SkipBuild,                         # only alias (no prisma/build/deploy)
  [string]$NodeVersion = ""                   # optional pin, e.g. "22.11.0"
)

# ---------- Helpers ----------
function Write-Info   ($m){ Write-Host $m -ForegroundColor Cyan }
function Write-OK     ($m){ Write-Host $m -ForegroundColor Green }
function Write-Warn   ($m){ Write-Host $m -ForegroundColor Yellow }
function Write-ErrMsg ($m){ Write-Host $m -ForegroundColor Red }
function Run-Cmd($cmd, $args){
  Write-Host "› $cmd $($args -join ' ')" -ForegroundColor DarkGray
  & $cmd @args
  if ($LASTEXITCODE -ne 0) { throw "Command failed: $cmd $($args -join ' ')" }
}
function Ensure-Tool($name){
  $found = Get-Command $name -ErrorAction SilentlyContinue
  if (-not $found){ throw "$name not found in PATH." }
  return $found.Source
}

# ---------- Start ----------
Set-Location $ProjectRoot
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logDir = Join-Path $ProjectRoot "deploy_logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$log = Join-Path $logDir "deploy_$stamp.log"

Write-Info "`n=== Truvern Deploy ==="
"Start: $(Get-Date)" | Out-File $log -Encoding UTF8

# Env / tools
$null = Ensure-Tool "node"
$null = Ensure-Tool "npm"
$null = Ensure-Tool "npx"

if ($NodeVersion){
  try   { Run-Cmd "nvm" @("use",$NodeVersion) 2>&1 | Tee-Object -FilePath $log -Append | Out-Null }
  catch { Write-Warn "nvm not available or version missing; continuing with current node." }
}

if (-not $env:VERCEL_TOKEN){
  Write-Warn "VERCEL_TOKEN not set. Proceeding without explicit token (CLI session auth will be used)."
}

# Link strategy
$vercelDir = Join-Path $ProjectRoot ".vercel"
if ($ForceRelink -and (Test-Path $vercelDir)){
  Write-Warn "Removing existing .vercel (ForceRelink)."
  Remove-Item -Recurse -Force $vercelDir
}

# Ensure logged-in session
Write-Info "Checking Vercel session..."
try {
  npx vercel whoami 2>&1 | Tee-Object -FilePath $log -Append | Out-Null
} catch {
  Write-Warn "Not signed in. Launching login..."
  Run-Cmd "npx" @("vercel","login")
}

# Link (Personal default; Team if provided)
if ($ForceRelink -or -not (Test-Path $vercelDir)){
  Write-Info ("Linking project (" + ($(if($Team){"Team: $Team"}else{"Personal"})) + ")...")
  if ($Team){
    # Team link
    if ($env:VERCEL_TOKEN){
      Run-Cmd "npx" @("vercel","link","--yes","--scope",$Team,"--token",$env:VERCEL_TOKEN)
    } else {
      Run-Cmd "npx" @("vercel","link","--yes","--scope",$Team)
    }
  } else {
    # Personal (no --scope)
    if ($env:VERCEL_TOKEN){
      Run-Cmd "npx" @("vercel","link","--yes","--token",$env:VERCEL_TOKEN)
    } else {
      Run-Cmd "npx" @("vercel","link","--yes")
    }
  }
}

# Build+Deploy (unless skipping)
$deployedUrl = ""
if (-not $SkipBuild){
  Write-Info "Generating Prisma client..."
  Run-Cmd "npx" @("prisma","generate") 2>&1 | Tee-Object -FilePath $log -Append | Out-Null

  Write-Info "Installing dependencies..."
  Run-Cmd "npm" @("ci") 2>&1 | Tee-Object -FilePath $log -Append | Out-Null

  Write-Info "Building Next.js..."
  Run-Cmd "npm" @("run","build") 2>&1 | Tee-Object -FilePath $log -Append | Out-Null

  Write-Info "Deploying to Vercel (prod)..."
  $deployArgs = @("vercel","deploy","--prod","--yes")
  if ($env:VERCEL_TOKEN){ $deployArgs += @("--token",$env:VERCEL_TOKEN) }
  $deployOut = (& npx @deployArgs 2>&1) | Tee-Object -FilePath $log -Append
  $deployedUrl = ($deployOut | Select-String -Pattern "https://.*\.vercel\.app").Matches.Value | Select-Object -First 1
  if (-not $deployedUrl){ throw "Could not parse deployment URL. See log: $log" }
  Write-OK "Production: $deployedUrl"
} else {
  Write-Warn "SkipBuild is ON. No new deploy will be created."
}

# Alias (optional)
if ($AliasDomain){
  Write-Info "Aliasing $AliasDomain ..."
  $targetUrl = $(if ($deployedUrl){ $deployedUrl } else { Read-Host "Enter deployment URL to alias (https://*.vercel.app)" })
  $aliasArgs = @("vercel","alias",$targetUrl,$AliasDomain)
  if ($env:VERCEL_TOKEN){ $aliasArgs += @("--token",$env:VERCEL_TOKEN) }
  $aliasOut = (& npx @aliasArgs 2>&1) | Tee-Object -FilePath $log -Append
  if ($aliasOut -match "Success|Aliased|now points to"){
    Write-OK "Aliased: $AliasDomain → $targetUrl"
  } elseif ($aliasOut -match "don't have access to the domain"){
    Write-ErrMsg "Alias failed: domain access mismatch (scope). Use -Team to deploy to the team that owns the domain, or omit -Team to use Personal."
    throw "Alias failed due to domain ownership."
  } else {
    Write-ErrMsg "Alias may have failed. Check log: $log"
    throw "Alias step did not return success marker."
  }
}

Write-OK "`nAll done. Log: $log"
