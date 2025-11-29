# ========================
# Phase122j-DeployStable.ps1
# Safe build + deploy + route verify for Truvern
# ========================
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# 0) Move to script folder (project root)
if ($MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $scriptDir = Get-Location
}
Set-Location $scriptDir

# Safety: never run from system32
if (($PWD.Path -replace '\\+$','').ToLower().EndsWith('\windows\system32')) {
    throw "Refusing to run from system32. Please cd to your project folder first."
}

# 1) Paths & logs
$proj = Split-Path -Leaf $PWD.Path
$team = 'nelson-addaes-projects'
$project = 'truvern'
$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$logDir = Join-Path $PWD 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }

$mainLog   = Join-Path $logDir "phase122j-$ts.log"
$buildLog  = Join-Path $logDir "pnpm-build-$ts.txt"
$deployLog = Join-Path $logDir "vercel-deploy-$ts.txt"

function Log([string]$msg) {
    $stamp = (Get-Date).ToString('HH:mm:ss')
    $line  = "[$stamp] $msg"
    Write-Host $line
    Add-Content -Path $mainLog -Value $line
}

# 2) Tool discovery
function Require-Cmd([string]$name,[string]$hintPath = $null) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }
    if ($hintPath -and (Test-Path $hintPath)) { return $hintPath }
    throw "Required command '$name' not found. Please install or add to PATH."
}

$nodePath   = Require-Cmd 'node'
$pnpmPath   = Require-Cmd 'pnpm'
$vercelPath = Require-Cmd 'vercel' "$env:USERPROFILE\AppData\Roaming\npm\vercel.cmd"

# 3) Basic sanity
if (-not (Test-Path '.\package.json'))       { throw "package.json is missing in $PWD" }
if (-not (Test-Path '.\app'))                { throw "app/ folder is missing (Next.js app dir)" }
if (-not (Test-Path '.\next.config.js'))     { Log "WARN: next.config.js not found – continuing" }

# 4) Build steps
Log "Running: pnpm install (safe)"
& $pnpmPath install --no-frozen-lockfile 2>&1 | Tee-Object -FilePath $buildLog -Append | Out-Host

Log "Running: prisma generate"
$localPrisma = Join-Path $PWD '.\node_modules\.bin\prisma.cmd'
if (Test-Path $localPrisma) {
    & $localPrisma generate 2>&1 | Tee-Object -FilePath $buildLog -Append | Out-Host
} else {
    & npx prisma generate 2>&1 | Tee-Object -FilePath $buildLog -Append | Out-Host
}

Log "Running: pnpm run build"
$build = Start-Process -FilePath $pnpmPath -ArgumentList @('run','build') -NoNewWindow -PassThru -RedirectStandardOutput $buildLog -RedirectStandardError $buildLog
$build.WaitForExit()
if ($build.ExitCode -ne 0) {
    Log "❌ Build failed (exit $($build.ExitCode)). See $buildLog"
    throw "Build failed."
}
Log "✅ Build succeeded."

# 5) Ensure project is linked
Log "Linking project to scope '$team' and project '$project' (idempotent)"
$link = Start-Process -FilePath $vercelPath -ArgumentList @('link','--yes','--scope',$team,'--project',$project) -NoNewWindow -PassThru -RedirectStandardOutput $deployLog -RedirectStandardError $deployLog
$link.WaitForExit()
if ($link.ExitCode -ne 0) {
    Log "⚠️ 'vercel link' returned $($link.ExitCode). Continuing; inspect $deployLog if deploy fails."
} else {
    Log "Project linked or already linked."
}

# 6) Deploy
Log "Deploying to production..."
$dep = Start-Process -FilePath $vercelPath -ArgumentList @('--prod','--yes') -NoNewWindow -PassThru -RedirectStandardOutput $deployLog -RedirectStandardError $deployLog
$dep.WaitForExit()
if ($dep.ExitCode -ne 0) {
    Log "❌ Deploy failed (exit $($dep.ExitCode)). See $deployLog"
    throw "Deploy failed."
}
Log "✅ Deploy finished. Log: $deployLog"

# 7) Post-deploy route verification
$domain = "https://truvern.com"
$routes = @(
  "$domain/",
  "$domain/trust-network",
  "$domain/vendors",
  "$domain/reports/board"
)

Log "Starting HTTP 200 verification..."
$all200 = $true
foreach ($u in $routes) {
    try {
        $r = Invoke-WebRequest -Uri $u -UseBasicParsing -Method GET -MaximumRedirection 5 -TimeoutSec 25
        if ($r.StatusCode -eq 200) {
            Write-Host ("OK  {0} -> 200" -f $u) -ForegroundColor Green
            Add-Content -Path $mainLog -Value ("OK  {0} -> 200" -f $u)
        } else {
            Write-Host ("FAIL {0} -> {1}" -f $u, $r.StatusCode) -ForegroundColor Yellow
            Add-Content -Path $mainLog -Value ("FAIL {0} -> {1}" -f $u, $r.StatusCode)
            $all200 = $false
        }
    } catch {
        Write-Host ("FAIL {0} -> {1}" -f $u, $_.Exception.Message) -ForegroundColor Red
        Add-Content -Path $mainLog -Value ("FAIL {0} -> {1}" -f $u, $_.Exception.Message)
        $all200 = $false
    }
}

if ($all200) {
    Log "All key routes HTTP 200: YES"
} else {
    Log "Some routes failed HTTP 200."
}

Log "Done."
Write-Host "Main log:   $mainLog"
Write-Host "Build log:  $buildLog"
Write-Host "Deploy log: $deployLog"
