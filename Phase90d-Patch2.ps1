# Phase90d-Patch2.ps1 — AutoLink + AutoPull + Merge + Deploy (non-interactive, safe)
$ProjectRoot = "C:\Users\MR.NELSON\Downloads\truvern"
$OrgSlug     = "nelson-addaes-projects"
$ProjectSlug = "truvern"
$Environment = "production"

function Fail($m){ Write-Host "✖ $m" -ForegroundColor Red; exit 1 }
function Info($m){ Write-Host "• $m" -ForegroundColor Cyan }
function Ok($m){ Write-Host "✔ $m" -ForegroundColor Green }

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

Set-Location $ProjectRoot
if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) { Fail "Vercel CLI not found. Run: npm i -g vercel" }
vercel whoami | Out-Null; if ($LASTEXITCODE -ne 0) { Fail "Not logged in. Run 'vercel login'." }

# Safe relink
if (-not (Test-Path ".vercel\project.json")) { if (Test-Path ".vercel") { Remove-Item -Recurse -Force ".vercel" } }
Info "Linking to $OrgSlug/$ProjectSlug ..."
vercel link --yes --project $ProjectSlug --scope $OrgSlug | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "vercel link failed." }
Ok "Linked."

# Pull Vercel envs to a temp file
$Pulled = ".env.__pulled"
Info "Pulling Vercel $Environment envs -> $Pulled ..."
vercel env pull --environment=$Environment $Pulled | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "vercel env pull failed." }

# Resolve values from common .env locations (fall back to pulled)
$Candidates = @(".env", ".env.production", ".env.local", "apps\tprm\.env", $Pulled) | ForEach-Object { Join-Path $ProjectRoot $_ }
function GetVal($k){ foreach($p in $Candidates){ $v = Read-EnvValue $k $p; if ($v) { return $v } } return $null }

$STRIPE_SECRET_KEY   = GetVal "STRIPE_SECRET_KEY"
$STRIPE_PUBLIC_KEY   = GetVal "STRIPE_PUBLIC_KEY"
$DATABASE_URL        = GetVal "DATABASE_URL"
$NEXT_PUBLIC_APP_URL = GetVal "NEXT_PUBLIC_APP_URL"

if (-not $STRIPE_SECRET_KEY)   { Fail "STRIPE_SECRET_KEY not found in any env file: $($Candidates -join ', ')" }
if (-not $STRIPE_PUBLIC_KEY)   { Fail "STRIPE_PUBLIC_KEY not found in any env file" }
if (-not $DATABASE_URL)        { Fail "DATABASE_URL not found in any env file" }
if (-not $NEXT_PUBLIC_APP_URL) { Fail "NEXT_PUBLIC_APP_URL not found in any env file" }

Ok "Env values resolved."

# Update Vercel envs
Vercel-Env-Set "STRIPE_SECRET_KEY"   $STRIPE_SECRET_KEY   $Environment
Vercel-Env-Set "STRIPE_PUBLIC_KEY"   $STRIPE_PUBLIC_KEY   $Environment
Vercel-Env-Set "DATABASE_URL"        $DATABASE_URL        $Environment
Vercel-Env-Set "NEXT_PUBLIC_APP_URL" $NEXT_PUBLIC_APP_URL $Environment
Ok "Vercel env updated ($Environment)."

# Sync & deploy
Info "Pulling envs locally ..."
vercel pull --yes --environment=$Environment | Out-Null
Info "Building ..."
vercel build --prod | Out-Null
Info "Deploying (prebuilt) ..."
vercel deploy --prebuilt --prod --yes | Out-Null

Ok "Phase90d-Patch2 complete: Auto-link, env merge, build, deploy — done."
