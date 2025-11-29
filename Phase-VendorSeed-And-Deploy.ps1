<#
  Phase-VendorSeed-And-Deploy.ps1
  Corrected version with HERE-STRING for TypeScript content.
#>

$ErrorActionPreference = "Stop"

$projectPath = "C:\Users\MR.NELSON\Downloads\truvern"
Set-Location $projectPath

Write-Host "📁 Working directory set to: $projectPath" -ForegroundColor Cyan

# 1) Ensure prisma folder exists
$prismaDir = Join-Path $projectPath "prisma"
if (-not (Test-Path $prismaDir)) {
    Write-Error "Prisma folder not found at $prismaDir"
    exit 1
}

# -----------------------------------------------------------
# 2) Correct HERE-STRING for prisma/seed.ts (THIS FIXES ERROR)
# -----------------------------------------------------------

$seedPath = Join-Path $prismaDir "seed.ts"

$seedContent = @"
import { prisma } from "../src/lib/prisma";

async function main() {
  await prisma.vendor.createMany({
    data: [
      { name: "Acme Payments", riskScore: 68 },
      { name: "Samsara IoT", riskScore: 72 },
      { name: "Geotab Fleet", riskScore: 80 },
      { name: "Stripe Services", riskScore: 55 },
    ],
    skipDuplicates: true,
  });

  console.log("🌱 Seeded vendors successfully");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
"@

Write-Host "📝 Writing prisma/seed.ts..." -ForegroundColor Yellow
$seedContent | Out-File -FilePath $seedPath -Encoding utf8 -Force
Write-Host "✅ prisma/seed.ts updated." -ForegroundColor Green

# -----------------------------------------------------------
# 3) Update package.json with Prisma seed command
# -----------------------------------------------------------

$packageJsonPath = Join-Path $projectPath "package.json"
$pkgRaw = Get-Content $packageJsonPath -Raw
$pkg = $pkgRaw | ConvertFrom-Json

if (-not $pkg.prisma) {
    $pkg | Add-Member -MemberType NoteProperty -Name "prisma" -Value (@{})
}

$pkg.prisma.seed = "ts-node prisma/seed.ts"

$pkg | ConvertTo-Json -Depth 20 | Out-File $packageJsonPath -Encoding utf8 -Force
Write-Host "✅ package.json prisma.seed set." -ForegroundColor Green

# -----------------------------------------------------------
# 4) Install ts-node + typescript
# -----------------------------------------------------------
Write-Host "📦 Installing ts-node + typescript..." -ForegroundColor Yellow
npm install -D ts-node typescript @types/node

# -----------------------------------------------------------
# 5) Run the Prisma seed
# -----------------------------------------------------------
Write-Host "🌱 Running database seed..." -ForegroundColor Yellow
npx prisma db seed
if ($LASTEXITCODE -ne 0) {
  Write-Error "Prisma db seed failed."
  exit 1
}

Write-Host "✅ Database seeded." -ForegroundColor Green

# -----------------------------------------------------------
# 6) Deploy to production (remote Vercel build)
# -----------------------------------------------------------
Write-Host "🚀 Deploying using Phase-CLI-Deploy.ps1..." -ForegroundColor Yellow
.\Phase-CLI-Deploy.ps1

# -----------------------------------------------------------
# 7) Production health check
# -----------------------------------------------------------
Write-Host "🩺 Running production health check..." -ForegroundColor Yellow
.\Phase-Prod-HealthCheck.ps1

Write-Host ""
Write-Host "🎉 Vendor seed + deploy + health check COMPLETE." -ForegroundColor Green
