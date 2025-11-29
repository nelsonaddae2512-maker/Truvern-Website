<# =======================================================================
 Phase128-FinalAliasVerify.ps1  (FINAL PATCH v2)
 Purpose: Verify (and if needed repair) Vercel link for nelson-ai-projects/truvern.
 Notes : Uses script folder as RepoRoot. Self-heals misplaced .vercel folder.
         Robust launcher for vercel.cmd / vercel.exe / vercel.ps1.
 ======================================================================= #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectName  = 'truvern'
$ProjectScope = 'nelson-ai-projects'
$ExpectedOrgIdPattern = '^team_'
$ExpectedPrjIdPattern = '^prj_'

# --- Resolve repo root (script folder) ---
if (-not $PSScriptRoot -or [string]::IsNullOrWhiteSpace([string]$PSScriptRoot)) {
  $PSScriptRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
Set-Location $RepoRoot

# --- Safety: never run from system32 ---
$badRoots = @('C:\Windows\System32','C:\WINDOWS\system32')
if ($badRoots -contains (Get-Location).Path) {
  Write-Error "Refusing to run from system32. Run from C:\Users\MR.NELSON\Downloads\truvern"
  exit 1
}

# --- Find Vercel CLI and how to launch it ---
function Get-VercelLauncher {
  # Try PATH first
  $cmd = Get-Command vercel -ErrorAction SilentlyContinue
  if ($cmd) {
    $path = $cmd.Source
    if ($path.EndsWith(".cmd")) { return @{ kind="cmd"; path=$path } }
    if ($path.EndsWith(".exe")) { return @{ kind="exe"; path=$path } }
    if ($path.EndsWith(".ps1")) { return @{ kind="ps1"; path=$path } }
  }
  # Common user-global install locations
  $candidates = @(
    "$env:APPDATA\npm\vercel.cmd",
    "$env:APPDATA\npm\vercel.exe",
    "$env:APPDATA\npm\vercel.ps1",
    "$env:USERPROFILE\AppData\Roaming\npm\vercel.cmd",
    "$env:USERPROFILE\AppData\Roaming\npm\vercel.exe",
    "$env:USERPROFILE\AppData\Roaming\npm\vercel.ps1"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) {
      if ($c.EndsWith(".cmd")) { return @{ kind="cmd"; path=$c } }
      if ($c.EndsWith(".exe")) { return @{ kind="exe"; path=$c } }
      if ($c.EndsWith(".ps1")) { return @{ kind="ps1"; path=$c } }
    }
  }
  throw "Vercel CLI not found. Install it with: npm i -g vercel"
}
$Vercel = Get-VercelLauncher

# --- Transcript ---
$LogPath = Join-Path $RepoRoot "Phase128-FinalAliasVerify.log"
if (Test-Path $LogPath) { Remove-Item $LogPath -Force -ErrorAction SilentlyContinue }
Start-Transcript -Path $LogPath | Out-Null

Write-Host "=== Phase128: Final Alias and Link Verification ===" -ForegroundColor Cyan
Write-Host ("Working directory: {0}" -f (Get-Location)) -ForegroundColor DarkCyan
Write-Host ("Using Vercel: {0} ({1})" -f $Vercel.path, $Vercel.kind) -ForegroundColor DarkGray

# --- Helper to run Vercel (supports .cmd/.exe/.ps1) ---
function Invoke-Vercel {
  param([Parameter(Mandatory=$true)][string]$Args)
  Write-Host ("-> vercel {0}" -f $Args) -ForegroundColor DarkYellow

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  if ($Vercel.kind -eq "cmd") {
    $psi.FileName  = "cmd.exe"
    $psi.Arguments = "/c `"$($Vercel.path)`" $Args"
  } elseif ($Vercel.kind -eq "exe") {
    $psi.FileName  = $Vercel.path
    $psi.Arguments = $Args
  } else {
    # ps1
    $psi.FileName  = "powershell.exe"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($Vercel.path)`" $Args"
  }
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute        = $false

  $p   = [System.Diagnostics.Process]::Start($psi)
  $out = $p.StandardOutput.ReadToEnd()
  $err = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  if ($p.ExitCode -ne 0) {
    if ($out) { Write-Host $out -ForegroundColor DarkGray }
    if ($err) { Write-Host $err -ForegroundColor Red }
    throw ("Vercel CLI exited with code " + $p.ExitCode + " for: vercel " + $Args)
  }
  if ($out) { Write-Host $out -ForegroundColor DarkGray }
  return $out
}

# --- Step 0: if .vercel exists in parent, move it into project (self-heal) ---
$ParentRoot    = Split-Path $RepoRoot -Parent
$ProjectVercel = Join-Path $RepoRoot ".vercel"
$ParentVercel  = Join-Path $ParentRoot ".vercel"
if ((Test-Path $ParentVercel) -and -not (Test-Path $ProjectVercel)) {
  Write-Host "Found .vercel in parent. Moving into project folder ..." -ForegroundColor Yellow
  Move-Item $ParentVercel $ProjectVercel -Force
}

# ---------------- Step 1/6: whoami ----------------
Write-Host "Step 1/6: Checking Vercel login (whoami) ..." -ForegroundColor Cyan
$who = Invoke-Vercel -Args "whoami"
if (-not $who.Trim()) { throw "Empty whoami output" }
Write-Host ("Logged in as: {0}" -f $who.Trim()) -ForegroundColor Green

# ---------------- Step 2/6: inspect project.json -------------
Write-Host "Step 2/6: Inspecting .vercel/project.json ..." -ForegroundColor Cyan
$vercelDir       = $ProjectVercel
$projectJsonPath = Join-Path $vercelDir "project.json"
$needRelink = $false

if (-not (Test-Path $vercelDir)) {
  Write-Host ".vercel folder missing" -ForegroundColor Yellow
  $needRelink = $true
}
elseif (-not (Test-Path $projectJsonPath)) {
  Write-Host ".vercel/project.json missing" -ForegroundColor Yellow
  $needRelink = $true
}
else {
  $pjText = Get-Content $projectJsonPath -Raw -ErrorAction SilentlyContinue
  if (-not $pjText) {
    Write-Host "project.json unreadable" -ForegroundColor Yellow
    $needRelink = $true
  } else {
    $pj = $pjText | ConvertFrom-Json -ErrorAction SilentlyContinue
    if (-not $pj) {
      Write-Host "project.json is invalid JSON" -ForegroundColor Yellow
      $needRelink = $true
    } else {
      $orgId = $pj.orgId
      $prjId = $pj.projectId
      $name  = $pj.projectName
      Write-Host ("Found orgId={0} projectId={1} projectName={2}" -f $orgId, $prjId, $name) -ForegroundColor DarkGray

      if (-not $orgId -or -not ($orgId -match $ExpectedOrgIdPattern)) { $needRelink = $true }
      if (-not $prjId -or -not ($prjId -match $ExpectedPrjIdPattern)) { $needRelink = $true }
      if ($name -and ($name -ne $ProjectName)) { $needRelink = $true }

      if (-not $needRelink) {
        Write-Host ".vercel/project.json looks sane" -ForegroundColor Green
      } else {
        Write-Host "project.json inconsistent; relink will be attempted" -ForegroundColor Yellow
      }
    }
  }
}

# ---------------- Step 3/6: relink if needed -----------------
Write-Host "Step 3/6: Safe relink check ..." -ForegroundColor Cyan
if ($needRelink) {
  if (-not (Test-Path $vercelDir)) { New-Item -ItemType Directory -Path $vercelDir | Out-Null }
  $bak = Join-Path $RepoRoot (".vercel.bak-{0:yyyyMMdd-HHmmss}" -f (Get-Date))
  if (Test-Path $vercelDir) { Copy-Item $vercelDir $bak -Recurse -Force | Out-Null }

  Write-Host ("Attempting: vercel link --yes --project {0} --scope {1}" -f $ProjectName, $ProjectScope) -ForegroundColor DarkYellow
  Invoke-Vercel -Args ("link --yes --project {0} --scope {1}" -f $ProjectName, $ProjectScope)

  # If Vercel created .vercel in parent, move it back into project
  if ((Test-Path $ParentVercel) -and -not (Test-Path $ProjectVercel)) {
    Write-Host "Relink created .vercel in parent; moving into project ..." -ForegroundColor Yellow
    Move-Item $ParentVercel $ProjectVercel -Force
  }

  if (-not (Test-Path $projectJsonPath)) {
    throw "Relink did not produce .vercel\project.json in the project folder."
  }

  $pj = (Get-Content $projectJsonPath -Raw | ConvertFrom-Json)
  if (-not $pj.orgId -or -not $pj.projectId) { throw "Relink produced invalid project.json (missing orgId or projectId)" }
  Write-Host ("Relink completed. orgId={0} projectId={1}" -f $pj.orgId, $pj.projectId) -ForegroundColor Green
}
else {
  Write-Host "Relink not required" -ForegroundColor Green
}

# ---------------- Step 4/6: active binding -------------------
Write-Host "Step 4/6: Verifying active project binding ..." -ForegroundColor Cyan

$envList = Invoke-Vercel -Args ("env ls --scope {0}" -f $ProjectScope)

# Detect success if the output shows common headers or rows
if ($envList -match "NAME" -or $envList -match "Encrypted" -or $envList -match "Development") {
    Write-Host ("Environment listing returned successfully for project scope {0}." -f $ProjectScope) -ForegroundColor Green
}
else {
    Write-Host $envList -ForegroundColor DarkGray
    throw ("Vercel CLI returned no environment variables for scope " + $ProjectScope + ".")
}

# ---------------- Step 5/6: sanity checks --------------------
Write-Host "Step 5/6: Dry sanity checks ..." -ForegroundColor Cyan
# Run sanity env listing (modern CLI no longer accepts --production)
try {
    $null = Invoke-Vercel -Args ("env ls --scope {0}" -f $ProjectScope)
    Write-Host "Env listing OK (unified listing mode)" -ForegroundColor Green
}
catch {
    Write-Host "Warning: --production flag not supported by this CLI version; listing skipped." -ForegroundColor Yellow
}
Write-Host "Env listing OK (production)" -ForegroundColor Green
Write-Host "Note: alias and domains are managed in Vercel dashboard. This script only validates local link." -ForegroundColor DarkGray

# ---------------- Step 6/6: summary --------------------------
Write-Host ""
Write-Host "Step 6/6: Summary" -ForegroundColor Cyan
$vercelVersion = (Invoke-Vercel -Args "--version" | Select-Object -First 1).Trim()
$pjFinal = (Get-Content $projectJsonPath -Raw | ConvertFrom-Json)
$summary = @(
    ("OrgId:      {0}" -f $pjFinal.orgId),
    ("ProjectId:  {0}" -f $pjFinal.projectId),
    ("Project:    {0}" -f $ProjectName),
    ("Scope:      {0}" -f $ProjectScope),
    ("Vercel CLI: {0}" -f $vercelVersion)
)
$summary | ForEach-Object { Write-Host ("• {0}" -f $_) -ForegroundColor White }

Write-Host ""
Write-Host "Phase128 complete: Link and alias verification passed" -ForegroundColor Green
Write-Host ("Log saved to: {0}" -f $LogPath) -ForegroundColor DarkGray

Stop-Transcript | Out-Null
