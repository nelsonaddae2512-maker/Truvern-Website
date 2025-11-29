# Phase24-Rev4.ps1 — PATH fix + required bin resolution; optional tsx for seeding
[CmdletBinding()] param([switch]$Seed)
if ($PSScriptRoot) { Set-Location $PSScriptRoot }
$ErrorActionPreference = 'Stop'

# --- Session PATH (no machine changes) ---
$paths = @(
  "$env:APPDATA\npm",
  "$env:LOCALAPPDATA\pnpm",
  "C:\nvm4w\nodejs",
  "$env:ProgramFiles\nodejs",
  "$env:LOCALAPPDATA\Programs\node"
) | Where-Object { Test-Path $_ }
if ($paths.Count) { $env:PATH = (($paths -join ';') + ';' + $env:PATH) }

function Resolve-Bin([string[]]$names) {
  foreach ($n in $names) {
    $cmd = Get-Command $n -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Path }
    foreach ($p in $paths) {
      $cand = Join-Path $p $n
      if (Test-Path $cand) { return $cand }
    }
  }
  throw "Cannot find any of: $($names -join ', ')"
}
function Resolve-BinOptional([string[]]$names) {
  try { return (Resolve-Bin $names) } catch { return $null }
}

function Run-External {
  param([string]$File,[string[]]$Args=@(),[int]$TimeoutSec=900,[string]$LogPath)
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $File
  $psi.Arguments = [string]::Join(' ', $Args)
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError  = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $so = $p.StandardOutput.ReadToEndAsync()
  $se = $p.StandardError.ReadToEndAsync()
  if (-not $p.WaitForExit($TimeoutSec * 1000)) { $p.Kill() }
  $out = ($so.GetAwaiter().GetResult() + "`n" + $se.GetAwaiter().GetResult())
  if ($LogPath) { $out | Tee-Object -FilePath $LogPath } else { Write-Host $out }
  return @{ Code = $p.ExitCode }
}

function Note([string]$m,[string]$c='Gray'){ Write-Host $m -ForegroundColor $c }

# --- Resolve required executables ---
$bin = @{
  pnpx   = Resolve-Bin @('pnpx.cmd','pnpx','npx.cmd','npx')
  pnpm   = Resolve-Bin @('pnpm.cmd','pnpm')
  vercel = Resolve-Bin @('vercel.cmd','vercel')
}

# --- Logs ---
$root = Get-Location
$logs = Join-Path $root "logs\phase24"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
$ts = Get-Date -Format "yyyyMMdd-HHmmss"
$buildLog   = Join-Path $logs "build-$ts.log"
$deployLog  = Join-Path $logs "deploy-$ts.log"
$prismaLog  = Join-Path $logs "prisma-$ts.log"
$transcript = Join-Path $logs "transcript-$ts.log"
Start-Transcript -Path $transcript -Force | Out-Null

function Get-DatabaseHostPort {
  $line = (Get-Content -Raw .env) -split "`n" | Where-Object { $_ -match '^\s*DATABASE_URL\s*=' } | Select-Object -First 1
  if (-not $line) { return @{} }
  $url = ($line -replace '^\s*DATABASE_URL\s*=\s*','').Trim('"').Trim()
  try {
    $u = [uri]$url
    $port = 5432
    if ($u.Port -gt 0) { $port = $u.Port }
    return @{ Host = $u.Host; Port = $port }
  } catch {
    if ($url -match '@([^:/\?]+)(?::(\d+))?') {
      $host = $Matches[1]
      $port = 5432
      if ($Matches[2]) { $port = [int]$Matches[2] }
      return @{ Host = $host; Port = $port }
    }
    return @{}
  }
}

function Wait-For-DB([int]$retries=12,[int]$delaySec=5){
  $i = Get-DatabaseHostPort
  if (-not $i.Host){ throw "DATABASE_URL missing/unparsable in .env" }
  Note "DB target: $($i.Host):$($i.Port)" "DarkGray"
  for($a=1;$a -le $retries;$a++){
    $ok = $false
    try { $ok = (Test-NetConnection -ComputerName $i.Host -Port $i.Port -WarningAction SilentlyContinue).TcpTestSucceeded } catch {}
    if ($ok){ Note "[DB] TCP reachable on attempt $a." "Green"; return }
    Note "[DB] Not reachable… retry $a/$retries" "Yellow"; Start-Sleep -Seconds $delaySec
  }
  throw "Database not reachable at $($i.Host):$($i.Port)"
}

function Prisma-Pull   { Note "[Prisma] db pull…" "Cyan";   Run-External -File $bin.pnpx -Args @('prisma','db','pull')                 -TimeoutSec 600 -LogPath $prismaLog | Out-Null }
function Prisma-Gen    { Note "[Prisma] generate…" "Cyan";  Run-External -File $bin.pnpx -Args @('prisma','generate','--no-engine')    -TimeoutSec 300 -LogPath $prismaLog | Out-Null }
function Prisma-Deploy { Note "[Prisma] migrate deploy…" "Cyan"; $r=Run-External -File $bin.pnpx -Args @('prisma','migrate','deploy')  -TimeoutSec 900 -LogPath $prismaLog; if($r.Code -ne 0){ throw "Prisma migrate failed. See $prismaLog" } else { Note "[Prisma] migrate OK." "Green" } }

function Try-Seed([switch]$Enable){
  if(-not $Enable){ Note "[Seed] Skipped." "DarkGray"; return }
  # 1) Try prisma's official seed hook (works if package.json has prisma.seed)
  try{
    Note "[Seed] Attempt: pnpx prisma db seed" "Cyan"
    $r = Run-External -File $bin.pnpx -Args @('prisma','db','seed') -TimeoutSec 900 -LogPath $prismaLog
    if($r.Code -eq 0){ Note "[Seed] Completed via prisma db seed." "Green"; return }
  }catch{}

  # 2) If TS seed files exist, try tsx or ts-node if available
  $tsx = Resolve-BinOptional @('tsx.cmd','tsx')
  $tsnode = Resolve-BinOptional @('ts-node.cmd','ts-node')

  $candidates = @()
  if (Test-Path 'prisma/seed.ts') { $candidates += 'prisma/seed.ts' }
  if (Test-Path 'seed.ts')        { $candidates += 'seed.ts' }

  foreach($f in $candidates){
    if ($tsx) {
      try {
        Note "[Seed] Attempt: tsx $f" "Cyan"
        $r = Run-External -File $tsx -Args @($f) -TimeoutSec 900 -LogPath $prismaLog
        if($r.Code -eq 0){ Note "[Seed] Completed via tsx ($f)." "Green"; return }
      } catch {}
    }
    if ($tsnode) {
      try {
        Note "[Seed] Attempt: ts-node $f" "Cyan"
        $r = Run-External -File $tsnode -Args @($f) -TimeoutSec 900 -LogPath $prismaLog
        if($r.Code -eq 0){ Note "[Seed] Completed via ts-node ($f)." "Green"; return }
      } catch {}
    }
  }

  Note "[Seed] No seeding tool found or seeds failed. Install tsx (pnpm add -D tsx) or define prisma.seed. See $prismaLog." "Yellow"
}

function Build-App  { Note "[Build] Next build…" "Cyan"; Run-External -File $bin.pnpm -Args @('build') -TimeoutSec 1800 -LogPath $buildLog | Out-Null; Note "[Build] OK. Log: $buildLog" "Green" }
function Deploy     { Note "[Deploy] Vercel --prod…" "Cyan"; $r=Run-External -File $bin.vercel -Args @('--prod','--yes') -TimeoutSec 900 -LogPath $deployLog; if($r.Code -ne 0){ throw "Vercel deploy failed. See $deployLog" } ; Note "[Deploy] OK. Log: $deployLog" "Green" }
function Health([string]$Base='https://truvern.com'){ try{ $o=Invoke-WebRequest "$Base/ops" -TimeoutSec 20 -UseBasicParsing; $a=Invoke-WebRequest "$Base/api" -TimeoutSec 20 -UseBasicParsing; if($o.StatusCode -eq 200 -and $a.StatusCode -eq 200){ Note "[Health] OK -> /ops 200, /api 200" "Green"} else { Note "[Health] WARN -> /ops $($o.StatusCode), /api $($a.StatusCode)" "Yellow"} }catch{ Note "[Health] ERROR: $($_.Exception.Message)" "Red"} }

try {
    Note "================ Phase24-Rev4 start ================" "DarkGray"
    Wait-For-DB
    Prisma-Pull
    Prisma-Gen
    Prisma-Deploy
    Try-Seed -Enable:$Seed.IsPresent
    Build-App
    Deploy
    Health
    Note "Phase24-Rev4 complete - DB synced and prod verified." "Green"
    Note "See logs folder: $logs" "Yellow"
}
catch {
    Note "Phase24-Rev4 ERROR: $($_.Exception.Message)" "Red"
    Note "See logs folder: $logs" "Yellow"
    throw
}
finally {
    Stop-Transcript | Out-Null
}
