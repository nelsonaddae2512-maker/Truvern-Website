<# =======================================================================
 Phase133-FinalSync-Fixed2.ps1
 Purpose: Final env sync + Prisma migrate with strict PS5-safe syntax.
 ======================================================================= #>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectName  = 'truvern'
$ProjectScope = 'nelson-ai-projects'

# Resolve repo root
if (-not $PSScriptRoot -or [string]::IsNullOrWhiteSpace([string]$PSScriptRoot)) {
  $PSScriptRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $PSScriptRoot).Path
Set-Location $RepoRoot

# Safety: never run from system32
$badRoots = @('C:\Windows\System32','C:\WINDOWS\system32')
if ($badRoots -contains (Get-Location).Path) {
  Write-Error 'Refusing to run from system32. Run from C:\Users\MR.NELSON\Downloads\truvern'
  exit 1
}

# Logging
$LogPath = Join-Path $RepoRoot 'Phase133-FinalSync-Fixed2.log'
if (Test-Path $LogPath) { Remove-Item $LogPath -Force -ErrorAction SilentlyContinue }
Start-Transcript -Path $LogPath | Out-Null

Write-Host '=== Phase133: Final Sync & Migration (Fixed2) ===' -ForegroundColor Cyan
Write-Host ('Repo Root: {0}' -f $RepoRoot) -ForegroundColor DarkCyan

# ---------------- Helpers ----------------
function Import-DotEnv {
  param([Parameter(Mandatory=$true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return 0 }
  $count = 0
  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { return }
    $idx = $line.IndexOf('=')
    if ($idx -lt 1) { return }
    $key = $line.Substring(0, $idx).Trim()
    $val = $line.Substring($idx + 1).Trim().Trim("'`"")
    if ($key) {
      [System.Environment]::SetEnvironmentVariable($key, $val, 'Process')
      $count++
    }
  }
  return $count
}

function Run-CLI {
  param([Parameter(Mandatory=$true)][string]$Cmd)
  Write-Host ('-> {0}' -f $Cmd) -ForegroundColor DarkYellow
  & cmd.exe /c $Cmd
  if ($LASTEXITCODE -ne 0) { throw ('Command failed: ' + $Cmd) }
}

# ------------- Step 1: .vercel + auth -------------
Write-Host 'Step 1/6: Verify .vercel and auth ...' -ForegroundColor Cyan
$VercelDir    = Join-Path $RepoRoot '.vercel'
$ParentVercel = Join-Path (Split-Path $RepoRoot -Parent) '.vercel'
if ((Test-Path $ParentVercel) -and -not (Test-Path $VercelDir)) {
  Move-Item $ParentVercel $VercelDir -Force
}

Run-CLI 'vercel whoami'

if (-not (Test-Path (Join-Path $VercelDir 'project.json'))) {
  Write-Host 'Link missing; running vercel link ...' -ForegroundColor Yellow
  Run-CLI ("vercel link --yes --project {0} --scope {1}" -f $ProjectName, $ProjectScope)
  if ((Test-Path $ParentVercel) -and -not (Test-Path $VercelDir)) { Move-Item $ParentVercel $VercelDir -Force }
  if (-not (Test-Path (Join-Path $VercelDir 'project.json'))) { throw '.vercel\project.json not found after link.' }
}
Write-Host 'Project link OK.' -ForegroundColor Green

# ------------- Step 2: Pull env -------------
Write-Host 'Step 2/6: Pulling production env ...' -ForegroundColor Cyan
Run-CLI ("vercel pull --environment=production --scope {0} --yes" -f $ProjectScope)

$EnvCandidates = @(
  (Join-Path $RepoRoot '.vercel\.env.production.local'),
  (Join-Path $RepoRoot '.vercel\.env.local'),
  (Join-Path $RepoRoot '.env.production.local'),
  (Join-Path $RepoRoot '.env.local'),
  (Join-Path $RepoRoot '.env')
)
$LoadedFrom = $null
foreach ($f in $EnvCandidates) {
  if (Test-Path $f) {
    $c = Import-DotEnv -Path $f
    if ($c -gt 0) { $LoadedFrom = $f; break }
  }
}
if ($LoadedFrom) {
  Write-Host ('Loaded vars from: {0}' -f $LoadedFrom) -ForegroundColor Green
} else {
  Write-Host 'No .env file found with values.' -ForegroundColor Yellow
}

# ------------- Step 3: Tools -------------
Write-Host 'Step 3/6: Checking Node and Prisma ...' -ForegroundColor Cyan
$nodeVer = (& node --version) 2>$null
if (-not $nodeVer) { throw 'Node.js not found on PATH. Please install Node 18+.' }
Write-Host ('Node: {0}' -f $nodeVer.Trim())
Run-CLI 'npx --yes prisma --version'

# ------------- Step 4: Find schema.prisma -------------
Write-Host 'Step 4/6: Locating schema.prisma ...' -ForegroundColor Cyan
$schemas = @(Get-ChildItem -Recurse -Filter 'schema.prisma' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
if ($schemas.Count -eq 0) {
  Write-Host 'No schema.prisma found; skipping.' -ForegroundColor Yellow
} else {
  foreach ($s in $schemas) { Write-Host ('Found: {0}' -f $s) -ForegroundColor Green }
}

# ------------- Step 5: Prisma migrate -------------
Write-Host 'Step 5/6: Running Prisma migrate deploy ...' -ForegroundColor Cyan
foreach ($schema in $schemas) {
  $dir = Split-Path $schema -Parent
  Push-Location $dir
  try {
    Run-CLI ("npx --yes prisma generate --schema `"{0}`"" -f $schema)
    Run-CLI ("npx --yes prisma migrate deploy --schema `"{0}`"" -f $schema)
    & cmd.exe /c ("npx --yes prisma db pull --print --schema `"{0}`"" -f $schema)
    if ($LASTEXITCODE -eq 0) {
      Write-Host 'DB pull succeeded (schema printed).' -ForegroundColor Green
    } else {
      Write-Host 'DB pull failed (non-blocking).' -ForegroundColor Yellow
    }
    Write-Host ('Prisma sync success for {0}' -f $schema) -ForegroundColor Green
  } catch {
    Write-Host ('Prisma error: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
  } finally {
    Pop-Location
  }
}

# ------------- Step 6: Summary -------------
Write-Host ''
Write-Host 'Step 6/6: Summary' -ForegroundColor Cyan

$projectJson = Join-Path $VercelDir 'project.json'
$orgId  = '<unknown>'
$projId = '<unknown>'
try {
  if (Test-Path $projectJson) {
    $pj = Get-Content $projectJson -Raw | ConvertFrom-Json
    if ($pj.orgId)    { $orgId  = $pj.orgId }
    if ($pj.projectId){ $projId = $pj.projectId }
  }
} catch { }

Write-Host ('OrgId:     {0}' -f $orgId)  -ForegroundColor White
Write-Host ('ProjectId: {0}' -f $projId) -ForegroundColor White
Write-Host ('Project:   {0}' -f $ProjectName) -ForegroundColor White
Write-Host ('Scope:     {0}' -f $ProjectScope) -ForegroundColor White

$loadedText = '<none>'
if ($LoadedFrom) { $loadedText = $LoadedFrom }
Write-Host ('Loaded .env from: {0}' -f $loadedText) -ForegroundColor White

Write-Host ('Log saved to: {0}' -f $LogPath) -ForegroundColor DarkGray
Write-Host 'Phase133 fixed2 complete.' -ForegroundColor Green
Stop-Transcript | Out-Null
