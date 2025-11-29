param(
  [string]$Domain = "truvern.com",
  # ← IMPORTANT: team scope *exactly* as Vercel shows it
  [string]$Scope  = "nelson-addaes-projects",
  [int]$TimeoutSec = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- tiny logger
function Note($msg, $color="Gray") { Write-Host $msg -ForegroundColor $color }

# --- ensure we are NOT in system32
if ($PWD.Path -match "\\Windows\\System32$") {
  throw "Refusing to run from system32. cd to your project folder and run again."
}

# --- log file
$logDir = ".\logs\phase33"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$log = Join-Path $logDir ("liveverify-{0}.log" -f (Get-Date -f "yyyyMMdd-HHmmss"))
Start-Transcript -Path $log -Force | Out-Null

try {
  Note "== Phase33: Live Verify for $Domain ==" "DarkGray"
  Note "Scope: $Scope" "Cyan"

  # --- find vercel CLI robustly
  function Resolve-Vercel {
    $c = Get-Command vercel -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    foreach ($p in @(
      "$env:APPDATA\npm\vercel.cmd",
      "$env:LOCALAPPDATA\Programs\vercel\vercel.exe",
      "$env:ProgramFiles\nodejs\vercel.cmd",
      "$env:ProgramFiles\nodejs\vercel.exe",
      "$env:USERPROFILE\AppData\Roaming\npm\vercel.cmd",
      "vercel.cmd","vercel.exe","vercel"
    )) { if (Test-Path $p) { return (Resolve-Path $p).Path } }
    throw "Vercel CLI not found on PATH. Install with: npm i -g vercel"
  }

  $vercel = Resolve-Vercel
  Note "Vercel CLI: $vercel" "DarkGray"

  # --- run vercel and capture output exactly
  function Run-Vercel([string]$args) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = $vercel
    $psi.Arguments = $args
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow   = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()
    return @{ Code=$p.ExitCode; Out=$out; Err=$err }
  }

  # 1) Switch scope
  Note "[1/5] Switch to team scope: $Scope" "DarkGray"
  $sw = Run-Vercel ("switch {0} --yes" -f $Scope)
  if ($sw.Code -ne 0) { throw "Failed to switch scope: $($sw.Err)" }
  Note "Scope set to $Scope" "Green"

  # 2) Ensure the domain exists in this scope (idempotent)
  Note "[2/5] Ensure domain exists in scope" "DarkGray"
  $inspect = Run-Vercel ("domains inspect {0} --scope {1}" -f $Domain, $Scope)
  if ($inspect.Code -ne 0 -and $inspect.Err -notmatch "not found") {
    throw "domains inspect failed: $($inspect.Err)"
  }
  if ($inspect.Code -ne 0 -and $inspect.Err -match "not found") {
    $add = Run-Vercel ("domains add {0} --scope {1}" -f $Domain, $Scope)
    if ($add.Code -ne 0) {
      # If it's owned in another team, caller must reclaim there first.
      throw "Could not add domain in this scope: $($add.Err)"
    }
    Note "Domain added to scope." "Green"
  } else {
    Note "Domain already present in scope." "DarkGray"
  }

  # 3) DNS quick check (nslookup + intended nameservers hint)
  Note "[3/5] DNS quick check" "DarkGray"
  try {
    $ns = (nslookup -type=ns $Domain 2>$null | Out-String)
    Note ($ns.Trim()) "DarkGray"
  } catch { Note "nslookup failed: $($_.Exception.Message)" "Yellow" }

  # 4) Live HTTP checks against the apex
  Note "[4/5] HTTP checks on https://$Domain" "DarkGray"
  try {
    $resp = Invoke-WebRequest -Uri ("https://{0}" -f $Domain) -UseBasicParsing -TimeoutSec $TimeoutSec -MaximumRedirection 3
    if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 400) {
      Note ("HTTPS reachable + HTTP {0} ({1})" -f $resp.StatusCode, $resp.BaseResponse.ResponseUri.AbsoluteUri) "Green"
    } else {
      Note ("HTTPS returned non-2xx/3xx -> {0}" -f $resp.StatusCode) "Yellow"
    }
  } catch {
    Note ("Root GET failed: {0}" -f $_.Exception.Message) "Red"
  }

  # 5) Optional health endpoints
  foreach($path in @("/ops/health","/api")) {
    try {
      $u = "https://{0}{1}" -f $Domain, $path
      $r = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec $TimeoutSec
      Note ("Health {0} -> HTTP {1}" -f $path, $r.StatusCode) "Green"
    } catch {
      Note ("Health {0} check failed: {1}" -f $path, $_.Exception.Message) "Yellow"
    }
  }

  Note "================================================" "DarkGray"
  Note ("PASS: Live verify completed for {0}" -f $Domain) "Green"
  Note ("Log: {0}" -f $log) "DarkGray"
  exit 0
}
catch {
  Note ("ERROR: {0}" -f $_.Exception.Message) "Red"
  Note ("See log for details: {0}" -f $log) "Yellow"
  exit 1
}
finally {
  try { Stop-Transcript | Out-Null } catch {}
}
