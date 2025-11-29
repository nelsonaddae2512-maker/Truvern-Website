# Phase125d-SafeAliasFinal.ps1
# Safely relinks Truvern project to correct team, updates alias, and verifies routes

$ErrorActionPreference = "Stop"

# ==== Configuration ====
$teamSlug = "nelson-ai-projects"
$project  = "truvern"
$domain   = "truvern.com"
$alsoWWW  = $true
# ========================

function Timestamp { (Get-Date).ToString("yyyyMMdd-HHmmss") }
function Log($msg, $color="Gray") {
  try { Write-Host $msg -ForegroundColor $color } catch { Write-Host $msg }
}

# Prepare logs
$logDir = Join-Path (Get-Location).Path "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$ts = Timestamp
$mainLog   = Join-Path $logDir "phase125d-main-$ts.log"
$aliasLog  = Join-Path $logDir "phase125d-alias-$ts.txt"
$verifyLog = Join-Path $logDir "route-public-verify-$ts.txt"

Start-Transcript -Path $mainLog | Out-Null

try {
  Log "=== Phase125d: Safe Alias Final ===" "Cyan"

  # Step 1: Check vercel CLI
  try {
    $vercelVersion = (& vercel --version 2>&1 | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($vercelVersion)) {
      throw "Vercel CLI not found. Install with: npm i -g vercel"
    }
    Log ("Vercel CLI detected: " + $vercelVersion) "Green"
  } catch {
    throw "Unable to execute 'vercel --version'. Ensure Vercel CLI is installed with: npm i -g vercel"
  }

  # Step 2: Link project
  Log "Linking project to team scope..." "Yellow"
  cmd /c "vercel link --yes --project $project --scope $teamSlug" 1>>"$aliasLog" 2>&1
  Log "Link confirmed for $teamSlug/$project." "Green"

  # Step 3: Find production deployment URL
  Log "Finding latest production deployment URL..." "Yellow"
  $lsOut = cmd /c "vercel ls $project --scope $teamSlug --prod --limit 1" 2>&1
  $prodUrl = [regex]::Match(($lsOut | Out-String), "https?://[a-z0-9-]+\.vercel\.app").Value
  if ([string]::IsNullOrWhiteSpace($prodUrl)) {
    throw "Could not determine production deployment URL."
  }
  Log ("Latest production URL: " + $prodUrl) "Green"

  # Step 4: Set aliases
  Log ("Setting alias: " + $prodUrl + " -> " + $domain) "Cyan"
  cmd /c "vercel alias --scope $teamSlug set $prodUrl $domain" 1>>"$aliasLog" 2>&1

  if ($alsoWWW) {
    $www = "www.$domain"
    Log ("Setting alias: " + $prodUrl + " -> " + $www) "Cyan"
    cmd /c "vercel alias --scope $teamSlug set $prodUrl $www" 1>>"$aliasLog" 2>&1
  }

  Log "Alias operations complete." "Green"

  # Step 5: Verify key routes
  Log "Verifying public routes for https://$domain ..." "Yellow"
  $routes = @(
    "/",
    "/pricing",
    "/login",
    "/subscribe",
    "/api/health",
    "/api/vendors",
    "/favicon.ico",
    "/manifest.json"
  )

  $base = "https://$domain"
  $allOk = $true
  foreach ($r in $routes) {
    $u = $base + $r
    try {
      $t0 = Get-Date
      $res = Invoke-WebRequest -UseBasicParsing -Method GET -Uri $u -TimeoutSec 25
      $ms = [int]((Get-Date) - $t0).TotalMilliseconds
      if ($res.StatusCode -eq 200) {
        $line = "OK  {0} -> 200  ({1} ms)" -f $u, $ms
        $line | Tee-Object -FilePath $verifyLog -Append | Out-Host
      } else {
        $allOk = $false
        $line = "ERR {0} -> {1}" -f $u, $res.StatusCode
        $line | Tee-Object -FilePath $verifyLog -Append | Out-Host
      }
    } catch {
      $allOk = $false
      $line = "ERR {0} -> {1}" -f $u, $_.Exception.Message
      $line | Tee-Object -FilePath $verifyLog -Append | Out-Host
    }
  }

  if ($allOk) {
    Log "All public routes returned HTTP 200." "Green"
  } else {
    Log "Some routes failed. Check verify log:" "Yellow"
  }

  Log "=== Phase125d complete ===" "Cyan"

} catch {
  Log ("ERROR: " + $_.Exception.Message) "Red"
} finally {
  try { Stop-Transcript | Out-Null } catch {}
  Log ("Main log: " + $mainLog) "DarkGray"
  Log ("Alias log: " + $aliasLog) "DarkGray"
  Log ("Verify log: " + $verifyLog) "DarkGray"
  Read-Host "Press Enter to close..."
}
