# Phase325E-CreateOrAttachClerkMembership.ps1
# Ensures a Clerk organization membership exists for a given user (robust + idempotent)
# PowerShell 5.1 compatible, ASCII-only (no emoji)

$ErrorActionPreference = "Stop"

$expectedRoot = "truvern"
if ($PWD.Path -match "\\Windows\\System32\\?$" -or $PWD.Path -notmatch $expectedRoot) {
  Write-Error "Refusing to run outside project root. Current path: $PWD"
  exit 1
}

$root = $PWD.Path
$logsDir = Join-Path $root "logs"
New-Item -ItemType Directory -Force -Path $logsDir | Out-Null

$logFile = Join-Path $logsDir "phase325e-clerk-membership.log"

function Log {
  param([string]$msg)
  $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  $line = "[$ts] $msg"
  Write-Host $line
  Add-Content -Path $logFile -Value $line
}

function MaskKey([string]$k) {
  if ([string]::IsNullOrWhiteSpace($k)) { return "" }
  $k = $k.Trim()
  if ($k.Length -le 10) { return "****" }
  return ($k.Substring(0,6) + "..." + $k.Substring($k.Length-4,4))
}

function GetEnvTrim([string]$name) {
  $v = [System.Environment]::GetEnvironmentVariable($name, "Process")
  if ($null -eq $v) { $v = [System.Environment]::GetEnvironmentVariable($name) }
  if ($null -eq $v) { return "" }
  return ($v.ToString()).Trim()
}

Log "=== Phase 325E: Clerk Org Membership Attach ==="

$envFile = Join-Path $root ".env"
if (-not (Test-Path $envFile)) {
  Log ("ERROR: .env not found at {0}" -f $envFile)
  exit 1
}

Get-Content $envFile | ForEach-Object {
  $line = $_
  if ($null -eq $line) { return }
  $line = $line.Trim()
  if (-not $line) { return }
  if ($line.StartsWith("#")) { return }

  $name = $null
  $value = $null

  if ($line -match '^\s*export\s+([^=]+)=(.*)$') {
    $name = $matches[1].Trim()
    $value = $matches[2].Trim()
  }
  elseif ($line -match '^\s*([^=]+)=(.*)$') {
    $name = $matches[1].Trim()
    $value = $matches[2].Trim()
  }
  else { return }

  if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
    if ($value.Length -ge 2) { $value = $value.Substring(1, $value.Length-2) }
  }

  [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
}

$secret = GetEnvTrim "CLERK_SECRET_KEY"
$orgId  = GetEnvTrim "TRUVERN_CLERK_ORG_ID"
$userId = GetEnvTrim "TRUVERN_DEV_USER_ID"

if ([string]::IsNullOrWhiteSpace($secret)) { Log "ERROR: CLERK_SECRET_KEY missing"; exit 1 }
if ([string]::IsNullOrWhiteSpace($orgId))  { Log "ERROR: TRUVERN_CLERK_ORG_ID missing"; exit 1 }
if ([string]::IsNullOrWhiteSpace($userId)) { Log "ERROR: TRUVERN_DEV_USER_ID missing"; exit 1 }

if ($secret -match '^(pk_|CLERK_PUBLISHABLE_KEY|NEXT_PUBLIC_)') {
  Log "ERROR: CLERK_SECRET_KEY looks like a publishable/public key (pk_...). Use sk_test_... or sk_live_..."
  exit 1
}
if ($secret -notmatch '^sk_(test|live)_' ) {
  Log "ERROR: CLERK_SECRET_KEY does not look like sk_test_... or sk_live_..."
  Log ("Provided: {0} (len={1})" -f (MaskKey $secret), $secret.Length)
  exit 1
}

Log ("Using OrgId={0} UserId={1}" -f $orgId, $userId)
Log ("CLERK_SECRET_KEY={0} (len={1})" -f (MaskKey $secret), $secret.Length)

$baseUrl = "https://api.clerk.com/v1"
$headers = @{
  "Authorization" = "Bearer $secret"
  "Content-Type"  = "application/json"
}

function Invoke-Clerk {
  param(
    [Parameter(Mandatory=$true)][string]$Method,
    [Parameter(Mandatory=$true)][string]$Url,
    $Body = $null
  )

  try {
    if ($null -ne $Body) {
      $json = $Body | ConvertTo-Json -Depth 10
      return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -Body $json
    } else {
      return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers
    }
  } catch {
    $resp = $_.Exception.Response
    $status = $null
    if ($resp -and $resp.StatusCode) { $status = [int]$resp.StatusCode }

    $raw = $null
    try {
      if ($resp) {
        $stream = $resp.GetResponseStream()
        if ($stream) {
          $reader = New-Object System.IO.StreamReader($stream)
          $raw = $reader.ReadToEnd()
        }
      }
    } catch {}

    if ($raw) {
      Log ("Clerk API error (HTTP {0}): {1}" -f $status, $raw)
      if ($raw -match '"code"\s*:\s*"clerk_key_invalid"') {
        Log "ERROR: Clerk says your secret key is invalid (clerk_key_invalid)."
      }
    } else {
      Log ("Clerk API error (HTTP {0}): {1}" -f $status, $_.Exception.Message)
    }

    throw
  }
}

Log "Checking Clerk user..."
Invoke-Clerk -Method "GET" -Url ($baseUrl + "/users/" + $userId) | Out-Null
Log "OK: Clerk user exists"

Log "Checking Clerk org..."
Invoke-Clerk -Method "GET" -Url ($baseUrl + "/organizations/" + $orgId) | Out-Null
Log "OK: Clerk organization exists"

Log "Checking existing memberships..."
$hasMembership = $false
$offset = 0
$limit = 100

while ($true) {
  $url = "{0}/organizations/{1}/memberships?limit={2}&offset={3}" -f $baseUrl, $orgId, $limit, $offset
  $page = Invoke-Clerk -Method "GET" -Url $url
  if ($null -eq $page) { break }

  $data = $page.data
  if ($null -ne $data) {
    foreach ($m in $data) {
      if ($m.public_user_data -and $m.public_user_data.user_id -eq $userId) {
        $hasMembership = $true
        Log ("INFO: User already a member of org (role={0})" -f $m.role)
        break
      }
    }
  }

  if ($hasMembership) { break }

  $total = 0
  try { $total = [int]$page.total_count } catch { $total = 0 }

  $offset += $limit
  if ($offset -ge $total -or $null -eq $data -or $data.Count -lt $limit) { break }
}

if ($hasMembership) {
  Log "=== Phase 325E complete (no action needed) ==="
  exit 0
}

Log "Creating Clerk organization membership..."
$body = @{
  user_id = $userId
  role    = "org:admin"
}

Invoke-Clerk -Method "POST" -Url ($baseUrl + "/organizations/" + $orgId + "/memberships") -Body $body | Out-Null
Log "OK: Membership successfully created"
Log "=== Phase 325E complete ==="
