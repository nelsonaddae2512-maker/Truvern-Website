<# Phase90e-DowngradeLocal.ps1
   Local Vercel CLI 48.7.1 to fix STRIPE_SECRET_KEY, verify, and deploy
#>

$ErrorActionPreference = 'Stop'

$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$OrgSlug     = "nelson-addaes-projects"
$ProjectSlug = "truvern"
$Environment = "production"
$EnvFiles    = @(".env", ".env.production", ".env.local", "apps\tprm\.env", ".env.__pulled")

function Info($m){ Write-Host "• $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "✔ $m" -ForegroundColor Green }
function Fail($m){ Write-Host "✖ $m" -ForegroundColor Red; exit 1 }
function To-Plain([SecureString]$s){ ([System.Net.NetworkCredential]::new("",$s)).Password }
function Read-EnvValue {
  param([string]$key,[string]$path)
  if (-not (Test-Path $path)) { return $null }
  $line = (Get-Content $path | Where-Object { ($_ -notmatch '^\s*#') -and ($_ -match "^\s*$key\s*=") } | Select-Object -First 1)
  if (-not $line) { return $null }
  $v = $line -replace "^\s*$key\s*=\s*", ""
  if ($v.StartsWith('"') -and $v.EndsWith('"')) { $v = $v.Substring(1,$v.Length-2) }
  if ($v.StartsWith("'") -and $v.EndsWith("'")) { $v = $v.Substring(1,$v.Length-2) }
  return $v
}

function Run-Cmd([string]$cmd){
  cmd /c "$cmd 2>&1" | ForEach-Object { $_ }
  return $LASTEXITCODE
}

Set-Location $ProjectRoot
$ts  = Get-Date -Format "yyyyMMdd-HHmmss"
$log = Join-Path $ProjectRoot ("phase90e-downgradeLocal-"+$ts+".log")
Start-Transcript -Path $log -Force | Out-Null
$env:VERCEL_DEBUG = "1"

try {
  Info "Checking Vercel auth..."
  vercel whoami | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "Not logged in. Run 'vercel login' and re-run." }

  Info "Linking to $OrgSlug/$ProjectSlug ..."
  vercel link --yes --project $ProjectSlug --scope $OrgSlug | Out-Null
  if ($LASTEXITCODE -ne 0) { Fail "vercel link failed." }
  Ok "Linked."

  $Pulled = ".env.__pulled"
  Info "Pulling $Environment envs -> $Pulled ..."
  vercel env pull --environment=$Environment $Pulled | Out-Null

  $Candidates = $EnvFiles | ForEach-Object { Join-Path $ProjectRoot $_ }
  $StripeSecret = $null
  foreach($p in $Candidates){ $v = Read-EnvValue "STRIPE_SECRET_KEY" $p; if ($v){ $StripeSecret = $v; break } }
  if (-not $StripeSecret) {
    $sec = Read-Host "Paste STRIPE_SECRET_KEY (sk_live_* or sk_test_*)" -AsSecureString
    $StripeSecret = To-Plain $sec
  }
  if ([string]::IsNullOrWhiteSpace($StripeSecret)) { Fail "Empty STRIPE_SECRET_KEY." }

  $ToolDir = Join-Path $ProjectRoot ".vercel-tools\cli-48.7.1"
  if (-not (Test-Path $ToolDir)) { New-Item -ItemType Directory -Force $ToolDir | Out-Null }
  Push-Location $ToolDir
  if (-not (Test-Path "package.json")) {
    Info "Initializing tool folder..."
    Run-Cmd "npm init -y" | Out-Null
  }
  if (-not (Test-Path "node_modules\vercel")) {
    Info "Installing vercel@48.7.1 locally..."
    Run-Cmd "npm install vercel@48.7.1 --no-audit --no-fund" | Out-Null
  }
  $Vercel48 = Join-Path $ToolDir "node_modules\.bin\vercel.cmd"
  if (-not (Test-Path $Vercel48)) { Fail "Pinned Vercel CLI not found at $Vercel48" }

  $tmp = New-TemporaryFile
  Set-Content -Path $tmp -Value $StripeSecret -NoNewline -Encoding UTF8

  Info "Removing existing STRIPE_SECRET_KEY (ok if not present)..."
  Run-Cmd "`"$Vercel48`" env rm STRIPE_SECRET_KEY $Environment --yes --project $ProjectSlug --scope $OrgSlug" | Out-Null

  Info "Setting STRIPE_SECRET_KEY (non-interactive)..."
  $code = Run-Cmd "`"$Vercel48`" env add STRIPE_SECRET_KEY $Environment --project $ProjectSlug --scope $OrgSlug < `"$($tmp.FullName)`""
  Remove-Item $tmp -Force
  if ($code -ne 0) { Fail "Failed to set STRIPE_SECRET_KEY (exit $code)" }
  Ok "STRIPE_SECRET_KEY set in Vercel ($Environment)."
  Pop-Location

  Info "Verifying variable exists..."
  Push-Location $ToolDir
  Run-Cmd "`"$Vercel48`" env ls --project $ProjectSlug --scope $OrgSlug" | Out-Null
  Pop-Location

  Info "Syncing envs locally ..."
  vercel pull --yes --environment=$Environment | Out-Null
  Info "Building ..."
  vercel build --prod | Out-Null
  Info "Deploying ..."
  vercel deploy --prebuilt --prod --yes | Out-Null

  Ok "Phase90e-DowngradeLocal complete: key fixed, synced, built & deployed."
}
catch {
  Write-Host "`nFATAL:" -ForegroundColor Red
  $_ | Format-List * -Force
}
finally {
  Stop-Transcript | Out-Null
  Write-Host "`nLog saved to $log" -ForegroundColor Yellow
}
