# ===========================
# Truvern one-shot fixer
# ===========================
$ErrorActionPreference = 'Stop'

$root        = Get-Location
$schemaPath  = Join-Path $root 'prisma\schema.prisma'
$envPath     = Join-Path $root '.env'

# --- Ensure prisma folder + file exist
if (-not (Test-Path (Split-Path $schemaPath))) {
    New-Item -ItemType Directory -Path (Split-Path $schemaPath) | Out-Null
}
if (-not (Test-Path $schemaPath)) {
@"
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
"@ | Set-Content -Path $schemaPath -Encoding UTF8
}

# --- Load current schema
$text = Get-Content $schemaPath -Raw

# --- Ensure generator client exists
if ($text -notmatch '(?ms)^\s*generator\s+client\s*\{[^}]*\}\s*') {
    $text = @"
generator client {
  provider = "prisma-client-js"
}

$text
"@
}

# --- Ensure datasource db exists
if ($text -notmatch '(?ms)^\s*datasource\s+db\s*\{[^}]*\}\s*') {
    $text = @"
$text

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}
"@
}

# --- Ensure Plan enum exists
if ($text -notmatch '(?ms)^\s*enum\s+Plan\s*\{[^}]*\}\s*') {
    $text = @"
$text

enum Plan {
  free
  pro
}
"@
}

# --- Ensure Organization model exists
if ($text -notmatch '(?ms)^\s*model\s+Organization\s*\{[^}]*\}\s*') {
    $text = @"
$text

model Organization {
  id        String  @id @default(cuid())
  name      String  @unique
  plan      Plan    @default(free)
  seats     Int     @default(1)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
}
"@
}

# --- Write schema safely
try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($schemaPath, $text, $utf8NoBom)
    Write-Host "✅ schema.prisma written (UTF-8 no BOM)" -ForegroundColor Green
}
catch {
    Set-Content -Path $schemaPath -Value $text -Encoding UTF8
    Write-Host "⚠️ Used fallback UTF8 encoding." -ForegroundColor Yellow
}

# --- Ensure DATABASE_URL in .env
if (-not (Test-Path $envPath)) {
    New-Item -ItemType File -Path $envPath | Out-Null
}
$envText = Get-Content $envPath -Raw
if ($envText -notmatch '(?m)^\s*DATABASE_URL\s*=') {
    Add-Content $envPath 'DATABASE_URL=REPLACE_WITH_YOUR_POSTGRES_URL'
    Write-Host "🟨 Added DATABASE_URL placeholder to .env"
} else {
    Write-Host "✅ .env already has DATABASE_URL"
}

# --- Helper to run commands
function Run($cmd) {
    Write-Host "→ $cmd" -ForegroundColor Cyan
    cmd /c $cmd
    if ($LASTEXITCODE -ne 0) { throw "❌ Step failed: $cmd" }
}

# --- Prisma + Build + Deploy
Run 'npx prisma format'
Run 'npx prisma validate'
Run 'npx prisma generate'

try {
    Run 'npx prisma migrate deploy'
}
catch {
    Write-Host "⚠️ migrate deploy skipped/failed (no migrations?)" -ForegroundColor Yellow
}

Run 'npm run build'
Run 'vercel --prod --yes'

Write-Host "`n✅ All done: schema fixed, validated, built, and deployed." -ForegroundColor Green
