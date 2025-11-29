# Phase122j2-DeployStable-ASCII.ps1  (plain ASCII, no emojis)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 0) Ensure we are not in system32
if (($PWD.Path -replace '\\+$','').ToLower().EndsWith('\windows\system32')) {
  throw 'Refusing to run from system32. cd to your project folder first.'
}

# 1) Paths & logs
$ts     = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path $PWD 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$mainLog   = Join-Path $logDir "phase122j2-$ts.log"
$buildLog  = Join-Path $logDir "pnpm-build-$ts.txt"
$deployLog = Join-Path $logDir "vercel-deploy-$ts.txt"

function Log([string]$m) {
  $line = ('[{0}] {1}' -f (Get-Date).ToString('HH:mm:ss'), $m)
  $line | Tee-Object -FilePath $mainLog -Append | Out-Host
}

# 2) Require tools
function Require-Cmd([string]$name,[string]$hint=$null) {
  $c = Get-Command $name -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  if ($hint -and (Test-Path $hint)) { return $hint }
  throw "Required command '$name' not found."
}
$node   = Require-Cmd 'node'
$pnpm   = Require-Cmd 'pnpm'
$vercel = Require-Cmd 'vercel' "$env:USERPROFILE\AppData\Roaming\npm\vercel.cmd"

# 3) Sanity
if (-not (Test-Path '.\package.json')) { throw 'package.json missing in current folder.' }
if (-not (Test-Path '.\app'))          { throw 'app/ folder (Next.js) missing.' }
if (-not (Test-Path '.\next.config.js')) { Log 'WARN: next.config.js not found - continuing.' }

# 4) Install, prisma, build
Log 'Running pnpm install --no-frozen-lockfile'
& $pnpm install --no-frozen-lockfile 2>&1 | Tee-Object -FilePath $buildLog -Append | Out-Host

Log 'Running prisma generate (safe execution mode)'

$prismaLocal = Join-Path $PWD '.\node_modules\.bin\prisma.cmd'
if (Test-Path $prismaLocal) {
    Log "Using local Prisma CLI at $prismaLocal"
    try {
        cmd /c "`"$prismaLocal`" generate" | Out-File -FilePath $buildLog -Append -Encoding utf8
        Log "✅ Prisma generate completed successfully."
    }
    catch {
        Log "⚠️ Prisma generate failed: $($_.Exception.Message)"
    }
} else {
    Log "Local Prisma not found. Using npx fallback..."
    try {
        cmd /c "npx prisma generate" | Out-File -FilePath $buildLog -Append -Encoding utf8
        Log "✅ Prisma generate completed successfully via npx."
    }
    catch {
        Log "⚠️ Prisma generate via npx failed: $($_.Exception.Message)"
    }
}

Log 'Running pnpm run build'
& $pnpm run build 2>&1 | Tee-Object -FilePath $buildLog -Append | Out-Host
if ($LASTEXITCODE -ne 0) {
  Log ('Build failed with exit {0}. See {1}' -f $LASTEXITCODE,$buildLog)
  throw 'Build failed.'
}
Log 'Build succeeded.'

# 5) Link project (idempotent)
$team    = 'nelson-addaes-projects'
$project = 'truvern'
Log ('Linking project to scope {0}, project {1}' -f $team,$project)
& $vercel link --yes --scope $team --project $project 2>&1 | Tee-Object -FilePath $deployLog -Append | Out-Host

# 6) Deploy production
Log 'Deploying with vercel --prod --yes'
& $vercel --prod --yes 2>&1 | Tee-Object -FilePath $deployLog -Append | Out-Host
if ($LASTEXITCODE -ne 0) {
  Log ('Deploy failed with exit {0}. See {1}' -f $LASTEXITCODE,$deployLog)
  throw 'Deploy failed.'
}
Log 'Deploy finished.'

# 7) Verify key routes
$domain = 'https://truvern.com'
$routes = @("$domain/","$domain/trust-network","$domain/vendors","$domain/reports/board")
Log 'Starting HTTP 200 verification...'
$all200 = $true
foreach($u in $routes){
  try{
    $r = Invoke-WebRequest -Uri $u -UseBasicParsing -Method GET -MaximumRedirection 5 -TimeoutSec 25
    if($r.StatusCode -eq 200){
      ('OK  {0} -> 200' -f $u) | Tee-Object -FilePath $mainLog -Append | Write-Host
    } else {
      ('FAIL {0} -> {1}' -f $u,$r.StatusCode) | Tee-Object -FilePath $mainLog -Append | Write-Host
      $all200 = $false
    }
  } catch {
    ('FAIL {0} -> {1}' -f $u,$_.Exception.Message) | Tee-Object -FilePath $mainLog -Append | Write-Host
    $all200 = $false
  }
}
if($all200){ Log 'All key routes HTTP 200: YES' } else { Log 'Some routes failed HTTP 200.' }

Log ('Main log:   {0}' -f $mainLog)
Log ('Build log:  {0}' -f $buildLog)
Log ('Deploy log: {0}' -f $deployLog)
