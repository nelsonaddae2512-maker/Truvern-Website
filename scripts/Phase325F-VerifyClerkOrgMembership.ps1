# Phase325F-VerifyClerkOrgMembership.ps1
# Verify Clerk org + user + membership (PS 5.1, StrictMode-safe, ASCII-only)

$ErrorActionPreference = "Stop"

# Safety: refuse system32
if ($PWD.Path -match "\\Windows\\System32") { throw "Refusing to run from system32" }

# Logging
$root = $PWD.Path
$logsDir = Join-Path $root "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
$logFile = Join-Path $logsDir "phase325f-clerk-membership-verify.log"

function Log([string]$msg) {
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $line = "[$ts] $msg"
  Write-Host $line
  Add-Content -Path $logFile -Value $line
}

function GetEnv([string]$name) {
  $v = [Environment]::GetEnvironmentVariable($name, "Process")
  if (-not $v) { $v = [Environment]::GetEnvironmentVariable($name) }
  if (-not $v) { return "" }
  return $v.Trim()
}

function HasProp($o, [string]$p) {
  if ($null -eq $o) { return $false }
  return ($o | Get-Member -Name $p -ErrorAction SilentlyContinue) -ne $null
}

function ToList($res) {
  if ($null -eq $res) { return @() }
  if ($res -is [Array]) { return $res }
  if (HasProp $res "data") {
    $d = $res.data
    if ($null -eq $d) { return @() }
    if ($d -is [Array]) { return $d }
    return @($d)
  }
  return @($res)
}

function MaskKey([string]$k) {
  if ([string]::IsNullOrWhiteSpace($k)) { return "" }
  $k = $k.Trim()
  if ($k.Length -le 10) { return "****" }
  return ($k.Substring(0,6) + "..." + $k.Substring($k.Length-4,4))
}

Log "=== Phase 325F: Verify Clerk Org Membership ==="

# Load .env into Process env
$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) { throw ".env not found at $envFile" }

# Warn about duplicate CLERK_SECRET_KEY lines
try {
  $lines = @(Get-Content $envFile | Select-String '^\s*CLERK_SECRET_KEY\s*=')
  if ($lines.Length -gt 1) {
    Log ("WARN: .env contains multiple CLERK_SECRET_KEY lines ({0}). Last one wins." -f $lines.Length)
  }
} catch {}

Get-Content $envFile | ForEach-Object {
  $l = $_
  if ($null -eq $l) { return }
  $l = $l.Trim()
  if (-not $l) { return }
  if ($l.StartsWith("#")) { return }

  if ($l -match '^\s*export\s+([^=]+)=(.*)$') {
    $n = $matches[1].Trim()
    $v = $matches[2].Trim().Trim("'`"")
    [Environment]::SetEnvironmentVariable($n, $v, "Process")
  } elseif ($l -match '^\s*([^=]+)=(.*)$') {
    $n = $matches[1].Trim()
    $v = $matches[2].Trim().Trim("'`"")
    [Environment]::SetEnvironmentVariable($n, $v, "Process")
  }
}

# Required vars
$secret = GetEnv "CLERK_SECRET_KEY"
$orgId  = GetEnv "TRUVERN_CLERK_ORG_ID"

# User resolution inputs (prefer email if present)
$email  = GetEnv "TRUVERN_DEV_USER_EMAIL"
$userId = GetEnv "TRUVERN_DEV_USER_ID"

if (-not $secret) { throw "CLERK_SECRET_KEY missing" }
if (-not $orgId)  { throw "TRUVERN_CLERK_ORG_ID missing" }

if ($secret -match '^(pk_|NEXT_PUBLIC_)') { throw "CLERK_SECRET_KEY looks like a public key. Use sk_test_/sk_live_." }
if ($secret -notmatch '^sk_(test|live)_') { throw "CLERK_SECRET_KEY must be sk_test_ or sk_live_" }

if (-not $email -and -not $userId) {
  throw "Provide TRUVERN_DEV_USER_EMAIL or TRUVERN_DEV_USER_ID for verification"
}

Log ("CLERK_SECRET_KEY={0} (len={1})" -f (MaskKey $secret), $secret.Length)
Log ("OrgId={0}" -f $orgId)
if ($email) { Log ("UserEmail={0}" -f $email) }
if ($userId) { Log ("UserId(env)={0}" -f $userId) }

# Clerk API
$base = "https://api.clerk.com/v1"
$headers = @{
  Authorization  = "Bearer $secret"
  "Content-Type" = "application/json"
}

function Call-Clerk($method, $url, $body = $null) {
  try {
    if ($null -ne $body) {
      $json = $body | ConvertTo-Json -Depth 10
      return Invoke-RestMethod -Method $method -Uri $url -Headers $headers -Body $json
    } else {
      return Invoke-RestMethod -Method $method -Uri $url -Headers $headers
    }
  } catch {
    $ex = $_.Exception
    $etype = ""
    $emsg = ""
    try { $etype = $ex.GetType().FullName } catch { $etype = "UnknownExceptionType" }
    try { $emsg = [string]$ex.Message } catch { $emsg = "" }

    $status = ""
    $bodyText = ""
    $resp = $null
    try { $resp = $ex.Response } catch { $resp = $null }
    if ($resp -ne $null) {
      try { $status = [string]([int]$resp.StatusCode) } catch { $status = "" }
      try {
        $stream = $resp.GetResponseStream()
        if ($stream) { $bodyText = (New-Object IO.StreamReader($stream)).ReadToEnd() }
      } catch { $bodyText = "" }
    }

    $fallback = ""
    try { $fallback = ($_ | Out-String).Trim() } catch { $fallback = "" }

    $parts = @()
    $parts += ("Method={0} Url={1}" -f $method, $url)
    if ($etype) { $parts += ("ExceptionType={0}" -f $etype) }
    if ($emsg)  { $parts += ("Message={0}" -f $emsg) }
    if ($status){ $parts += ("HTTP={0}" -f $status) }
    if ($bodyText) { $parts += ("Body={0}" -f $bodyText) }
    if (-not $bodyText -and $fallback) { $parts += ("Details={0}" -f $fallback) }

    throw ("Clerk API error: " + ($parts -join " | "))
  }
}

function ResolveUserIdByEmail([string]$addr) {
  if (-not $addr) { return "" }
  $q = [Uri]::EscapeDataString($addr)
  $res = Call-Clerk "GET" ("$base/users?email_address=$q&limit=10")
  $users = ToList $res

  foreach ($u in $users) {
    if ($null -eq $u) { continue }

    if (HasProp $u "email_addresses") {
      foreach ($ea in (ToList $u.email_addresses)) {
        if ($null -ne $ea -and (HasProp $ea "email_address") -and ($ea.email_address -eq $addr)) {
          if (HasProp $u "id") { return $u.id }
        }
      }
    }
  }

  # Fallback: if only one returned and has id
  $arr = ToList $users
  if (($arr -is [Array]) -and ($arr.Length -eq 1)) {
    $one = $arr[0]
    if ($null -ne $one -and (HasProp $one "id")) { return $one.id }
  }

  return ""
}

# Resolve userId
$resolvedUserId = ""
if ($email) {
  Log "Resolving user by email..."
  $resolvedUserId = ResolveUserIdByEmail $email
  if (-not $resolvedUserId) { throw "No Clerk user found for email in this environment." }
  Log ("Resolved UserId={0}" -f $resolvedUserId)
} else {
  $resolvedUserId = $userId
  Log ("Using provided UserId={0}" -f $resolvedUserId)
}

# Verify user exists (GET by id) — now that we have an id
Log "Verifying Clerk user exists..."
Call-Clerk "GET" ("$base/users/$resolvedUserId") | Out-Null
Log "OK: User verified"

# Verify org exists
Log "Verifying Clerk org exists..."
Call-Clerk "GET" ("$base/organizations/$orgId") | Out-Null
Log "OK: Org verified"

# Check membership (first page; good enough for most orgs; can be expanded later)
Log "Checking membership..."
$memRes = Call-Clerk "GET" ("$base/organizations/$orgId/memberships?limit=100&offset=0")
$memberships = ToList $memRes

$found = $false
$foundRole = ""

foreach ($m in $memberships) {
  if ($null -eq $m) { continue }
  if (HasProp $m "public_user_data") {
    $p = $m.public_user_data
    if ($null -ne $p -and (HasProp $p "user_id") -and ($p.user_id -eq $resolvedUserId)) {
      $found = $true
      if (HasProp $m "role") { $foundRole = [string]$m.role }
      break
    }
  }
}

if (-not $found) {
  Log "ERROR: Membership NOT found for user in org."
  Log "HINT: Run Phase325E to create it."
  throw "Membership missing"
}

Log ("OK: Membership found (role={0})" -f $foundRole)
Log "=== Phase 325F complete ==="
