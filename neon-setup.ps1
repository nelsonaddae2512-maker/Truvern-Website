$ErrorActionPreference = "Stop"

function Ensure-Ssl($u){
  if (-not $u) { throw "URL is empty." }
  $u = $u.Trim()
  if ($u -notmatch '^postgresql://') { throw "URL must start with postgresql://"; }
  if ($u -match '\?') {
    if ($u -notmatch 'sslmode=') { return "$u&sslmode=require" } else { return $u }
  } else {
    if ($u -notmatch 'sslmode=') { return "$u?sslmode=require" } else { return $u }
  }
}

Write-Host "Neon setup starting..." -ForegroundColor Cyan
$pooler = Read-Host "Paste POOLER URL (postgresql://...)"
$direct = Read-Host "Paste DIRECT URL (postgresql://...)"

$pooler = Ensure-Ssl $pooler
$direct = Ensure-Ssl $direct

$envText = @"
# generated $(Get-Date -Format s)
DATABASE_URL=$pooler
DIRECT_DATABASE_URL=$direct
SHADOW_DATABASE_URL=$direct
"@.Trim() + "`r`n"

Set-Content -Path ".env" -Value $envText -Encoding utf8
Write-Host "Wrote .env" -ForegroundColor Green
Write-Host ("DATABASE_URL host: {0}" -f ([uri]$pooler).Host)
Write-Host ("DIRECT_DATABASE_URL host: {0}" -f ([uri]$direct).Host)

# Optional: quick Prisma sync (safe to skip if Prisma not installed yet)
try {
  Write-Host "Running: npx prisma generate" -ForegroundColor DarkCyan
  npx prisma generate
  Write-Host "Running: npx prisma db push" -ForegroundColor DarkCyan
  npx prisma db push
} catch {
  Write-Host "Prisma step failed (you can run it later after verifying DB login)." -ForegroundColor Yellow
  Write-Host $_.Exception.Message
  if ($_.InvocationInfo.PositionMessage) { Write-Host "`n$($_.InvocationInfo.PositionMessage)" }
}

Write-Host "Neon setup finished." -ForegroundColor Green