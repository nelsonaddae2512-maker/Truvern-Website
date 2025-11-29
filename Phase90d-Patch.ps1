<# Phase90d-Patch.ps1 — Auto-link & AutoEnv & Deploy (safe + non-interactive) #>

$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$OrgSlug     = "nelson-addaes-projects"
$ProjectSlug = "truvern"
$EnvFile     = ".env"
$Environment = "production"

function Fail($m){ Write-Host "✖ $m" -ForegroundColor Red; exit 1 }
function Info($m){ Write-Host "• $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "✔ $m" -ForegroundColor Green }

Set-Location $ProjectRoot
Write-Host "`n=== Phase90d-Patch - AutoLink & AutoEnv & Deploy ===`n" -ForegroundColor Cyan

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

function Vercel-Env-Set {
  param([string]$name,[string]$value,[string]$env)
  if ([string]::IsNullOrWhiteSpace($value)) { Fail "Missing value for $name" }
  $tmp = New-TemporaryFile
  Set-Content -Path $tmp -Value $value -NoNewline -Encoding UTF8
  vercel env rm $name $env --yes 1>$null 2>$null
  Info "Setting $name ($env)..."
  cmd /c "type `"$($tmp.FullName)`" | vercel env add $name $env --yes"
  $code = $LASTEXITCODE
  Remove-Item $tmp -Force
  if ($code -ne 0) { Fail "Failed to set $name in $env (exit $code)" }
}

Info "Checking Vercel CLI..."
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) { Fail "Vercel CLI not found. Install: npm i -g vercel" }

Info "Verifying Vercel authentication..."
vercel whoami | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "Not logged in. Run 'vercel login' and re-run." }

# Safe relink
$projectJson = ".vercel\project.json"
$needsRelink = $true
if (Test-Path $projectJson) {
  try { $cfg = Get-Content $projectJson | ConvertFrom-Json; if ($cfg.projectId) { $needsRelink = $false; Ok "Existing .vercel found; keeping." } } catch { $needsRelink = $true }
}
if ($needsRelink) { Info "Preparing clean link..."; if (Test-Path ".vercel") { Remove-Item -Recurse -Force ".vercel" } }

Info "Linking to $OrgSlug/$ProjectSlug ..."
vercel link --yes --project $ProjectSlug --scope $OrgSlug | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "vercel link failed. Try manual: vercel link --yes --project truvern --scope nelson-addaes-projects" }
Ok "Linked to $OrgSlug/$ProjectSlug."

# Load envs
$envPath = Join-Path $ProjectRoot $EnvFile
Info "Reading env values from $envPath ..."
$STRIPE_SECRET_KEY    = Read-EnvValue "STRIPE_SECRET_KEY"    $envPath
$STRIPE_PUBLIC_KEY    = Read-EnvValue "STRIPE_PUBLIC_KEY"    $envPath
$DATABASE_URL         = Read-EnvValue "DATABASE_URL"         $envPath
$NEXT_PUBLIC_APP_URL  = Read-EnvValue "NEXT_PUBLIC_APP_URL"  $envPath
if (-not $STRIPE_SECRET_KEY)   { Fail "STRIPE_SECRET_KEY not found in $EnvFile" }
if (-not $STRIPE_PUBLIC_KEY)   { Fail "STRIPE_PUBLIC_KEY not found in $EnvFile" }
if (-not $DATABASE_URL)        { Fail "DATABASE_URL not found in $EnvFile" }
if (-not $NEXT_PUBLIC_APP_URL) { Fail "NEXT_PUBLIC_APP_URL not found in $EnvFile" }

# Push envs
Vercel-Env-Set "STRIPE_SECRET_KEY"   $STRIPE_SECRET_KEY   $Environment
Vercel-Env-Set "STRIPE_PUBLIC_KEY"   $STRIPE_PUBLIC_KEY   $Environment
Vercel-Env-Set "DATABASE_URL"        $DATABASE_URL        $Environment
Vercel-Env-Set "NEXT_PUBLIC_APP_URL" $NEXT_PUBLIC_APP_URL $Environment
Ok "Environment values updated in Vercel ($Environment)."

# Sync & deploy
Info "Pulling envs ..."
vercel pull --yes --environment=$Environment | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "vercel pull failed." }

Info "Building ..."
vercel build --prod | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "vercel build failed." }

Info "Deploying (prebuilt) ..."
vercel deploy --prebuilt --prod --yes | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "vercel deploy failed." }

Ok "Phase90d-Patch complete: Auto-link, env sync, build, deploy — done."
