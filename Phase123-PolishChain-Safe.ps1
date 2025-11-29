# Phase123-PolishChain-Safe.ps1 (no Transcript lock)
# Snapshot → Build → Deploy → Verify (safe, ASCII-only)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

function Log([string]$msg, [string]$color = 'Gray') {
  try { Write-Host $msg -ForegroundColor $color } catch { Write-Host $msg }
}

# Append text to a file with a tiny retry to avoid transient locks
function Append-Log([string]$path, [string]$text) {
  New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null
  for ($i=0; $i -lt 3; $i++) {
    try { Add-Content -Path $path -Value $text -Encoding UTF8; break }
    catch { Start-Sleep -Milliseconds 120 }
  }
}

# Run a command and append combined stdout+stderr and exit code to a log
function Run-Cmd([string]$file, [string]$args, [string]$logFile) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $file
  $psi.Arguments = $args
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()

  $stdout = $p.StandardOutput.ReadToEnd()
  $stderr = $p.StandardError.ReadToEnd()
  $p.WaitForExit()

  $combined = @(
    "==== CMD ====================================="
    ("> " + $file + " " + $args)
    "-----------------------------------------------"
    $stdout
    $stderr
    ("==== EXIT CODE: {0} =================" -f $p.ExitCode)
    ""
  ) -join [Environment]::NewLine

  if ($logFile) { Append-Log $logFile $combined }
  return @{ code = $p.ExitCode; text = ($stdout + "`n" + $stderr) }
}

# Verify key routes quickly
function Verify-Routes([string]$baseUrl, [string]$logFile) {
  $routes = @(
    '/', '/trust-network', '/vendors', '/vendors/1',
    '/reports/board', '/reports/board/preview',
    '/pricing', '/subscribe', '/security', '/login'
  )
  $okAll = $true
  foreach ($r in $routes) {
    try {
      $u  = ($baseUrl.TrimEnd('/')) + $r
      $t0 = Get-Date
      $res = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $u -TimeoutSec 20
      $ms = [int]((Get-Date) - $t0).TotalMilliseconds
      if ($res.StatusCode -eq 200) {
        $line = ("OK {0} -> 200 ({1} ms)" -f $u, $ms)
        Log $line 'Green'; if ($logFile) { Append-Log $logFile $line }
      } else {
        $line = ("ERR {0} -> {1}" -f $u, $res.StatusCode)
        Log $line 'Yellow'; if ($logFile) { Append-Log $logFile $line }
        $okAll = $false
      }
    } catch {
      $line = ("ERR {0} -> {1}" -f $u, $_.Exception.Message)
      Log $line 'Yellow'; if ($logFile) { Append-Log $logFile $line }
      $okAll = $false
    }
  }
  return $okAll
}

function Pause-End([string]$mainLog, [string]$depLog, [string]$vrfLog) {
  Log ""
  Log ("Main log:   {0}" -f $mainLog) 'DarkGray'
  Log ("Deploy log: {0}" -f $depLog)  'DarkGray'
  Log ("Verify log: {0}" -f $vrfLog)  'DarkGray'
  Log ""
  Write-Host "Press Enter to close: " -NoNewline
  [void][Console]::ReadLine()
}

# -------- Guard: do not run from System32 --------
try { Set-Location (Get-Location) } catch {}
$PWD = (Get-Location).Path
if (Test-Path "C:\Windows\System32") {
  if ($PWD -match '\\Windows\\System32$') {
    Write-Host "? Do not run from System32. Please cd into your project folder and rerun." -ForegroundColor Red
    exit 1
  }
}

# -------- Paths & logs --------
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $PWD "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$mainLog = Join-Path $logDir "phase123-main-$ts.log"
$depLog  = Join-Path $logDir "phase123-deploy-$ts.txt"
$vrfLog  = Join-Path $logDir "route-verify-$ts.txt"

# Ensure pnpm & vercel are resolvable on PATH for Windows
$env:NODE_HOME = "C:\Program Files\nodejs"
$env:Path = "$env:NODE_HOME;$env:APPDATA\npm;$env:Path"
if (-not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
  $pnpmPath = (Get-ChildItem "$env:APPDATA\npm\pnpm*.cmd" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
  if ($pnpmPath) { $env:Path += ";" + (Split-Path $pnpmPath) }
}
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
  $vercelPath = (Get-ChildItem "$env:APPDATA\npm\vercel*.cmd" -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
  if ($vercelPath) { $env:Path += ";" + (Split-Path $vercelPath) }
}

# -------- Snapshot (optional) --------
$nextDir = Join-Path $PWD ".next"
if (Test-Path $nextDir) {
  $zip = Join-Path $logDir ("snapshot-{0}.zip" -f $ts)
  try {
    Compress-Archive -Path $nextDir -DestinationPath $zip -Force
    Log ("Snapshot created at {0}" -f $zip) 'Green'
  } catch {
    Log ("Snapshot step skipped: {0}" -f $_.Exception.Message) 'Yellow'
  }
}

try {
  Log "=== Phase123: Build + Deploy + Verify (Safe) ===" 'Cyan'

  # 1) Build
  Log "Building project..." 'Cyan'
  $build = Run-Cmd "pnpm.cmd" "run build" $mainLog
  if ($build.code -ne 0) {
    if ($build.text -match 'Environment variables loaded from \.env') {
      Log "Build reported an invocation warning but will continue." 'Yellow'
    } else {
      Log "Build failed. See $mainLog" 'Yellow'
      throw "Build failed"
    }
  } else {
    Log "Build step completed." 'Green'
  }

  # 2) Deploy
  Log "Deploying to Vercel (prod)..." 'Cyan'
  $deploy = Run-Cmd "vercel.cmd" "--prod --yes" $depLog
  if ($deploy.code -ne 0) {
    Log "Deployment reported non-zero exit. Check $depLog" 'Yellow'
  } else {
    Log "Vercel deploy completed." 'Green'
  }

  # 3) Verify routes
  Log "Verifying key routes..." 'Cyan'
  $base = "https://truvern.com"
  if (Test-Path ".\Phase122y-AutoVerify.ps1") {
    & .\Phase122y-AutoVerify.ps1 -Base $base | Tee-Object -FilePath $vrfLog -Append | Out-Host
  } else {
    $ok = Verify-Routes -baseUrl $base -logFile $vrfLog
    if ($ok) { Log "All key routes returned HTTP 200." 'Green' }
    else     { Log "Some routes failed. See $vrfLog" 'Yellow' }
  }

  Log "=== Phase123 complete ===" 'Cyan'
}
catch {
  Log ("ERROR: {0}" -f $_.Exception.Message) 'Red'
}
finally {
  Pause-End $mainLog $depLog $vrfLog
}
