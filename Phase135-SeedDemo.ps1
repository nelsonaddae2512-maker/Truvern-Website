$ErrorActionPreference = "Stop"

Write-Host "=== Phase135: Seed Demo Vendors + Assessments ===" -ForegroundColor Cyan

$root = $PSScriptRoot
Set-Location $root
Write-Host "[INFO] Working in: $root" -ForegroundColor DarkCyan

# Ensure prisma directory exists
$prismaDir = Join-Path $root "prisma"
if (-not (Test-Path $prismaDir)) {
    New-Item -ItemType Directory -Path $prismaDir | Out-Null
    Write-Host "[INFO] Created prisma directory." -ForegroundColor Yellow
}

$seedFile = Join-Path $prismaDir "demo-seed.cjs"

Write-Host "[INFO] Writing demo seed script to $seedFile" -ForegroundColor Cyan

@'
/**
 * Demo seed script for Truvern
 * - Populates ~20 vendors with realistic risk scores
 * - Adds 1–4 assessments per vendor over the last 18 months
 * - Only runs if there are currently zero vendors
 */

const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

function monthsAgo(n) {
  const d = new Date();
  d.setMonth(d.getMonth() - n);
  return d;
}

const demoVendors = [
  { name: "CloudCore Infrastructure", riskScore: 82 },
  { name: "Atlas Identity Services", riskScore: 74 },
  { name: "Northwind Logistics", riskScore: 58 },
  { name: "Beacon Payments", riskScore: 90 },
  { name: "BlueSky Analytics", riskScore: 67 },
  { name: "Pixel CRM Solutions", riskScore: 43 },
  { name: "Evergreen HR Systems", riskScore: 36 },
  { name: "Summit Legal Review", riskScore: 52 },
  { name: "Helios Marketing Cloud", riskScore: 61 },
  { name: "Aurora Data Center", riskScore: 79 },
  { name: "Copperline Vendors", riskScore: 25 },
  { name: "Silver Oak Consultants", riskScore: 48 },
  { name: "Nimbus Email Relay", riskScore: 71 },
  { name: "Granite Security Ops", riskScore: 88 },
  { name: "Harborline Finance Tech", riskScore: 63 },
  { name: "Orbit Device Management", riskScore: 54 },
  { name: "Vertex Cloud Backup", riskScore: 69 },
  { name: "Liongate Vendor Portal", riskScore: 41 },
  { name: "Nova Support Desk", riskScore: 33 },
  { name: "Citrine Data Processing", riskScore: 77 },
];

function riskLevelFromScore(score) {
  if (score >= 80) return 4; // critical
  if (score >= 60) return 3; // high
  if (score >= 40) return 2; // medium
  return 1;                  // low
}

async function main() {
  console.log("=== Truvern demo seed starting ===");

  const vendorCount = await prisma.vendor.count();
  if (vendorCount > 0) {
    console.log(
      `Vendor table already has ${vendorCount} record(s). Demo seed will NOT run to avoid overwriting real data.`
    );
    return;
  }

  console.log("No vendors found. Seeding demo data...");

  for (let i = 0; i < demoVendors.length; i++) {
    const v = demoVendors[i];
    const score = v.riskScore;
    const level = riskLevelFromScore(score);

    // Create between 1 and 4 assessments with different dates
    const assessments = [
      {
        riskLevel: level,
        createdAt: monthsAgo(1),
      },
      {
        riskLevel: level,
        createdAt: monthsAgo(6),
      },
      {
        riskLevel: level,
        createdAt: monthsAgo(12),
      },
    ];

    // Randomly decide whether to include all 3 or just 1–2
    const take = 1 + Math.floor(Math.random() * assessments.length);
    const subset = assessments.slice(0, take);

    await prisma.vendor.create({
      data: {
        name: v.name,
        riskScore: score,
        assessments: {
          create: subset,
        },
      },
    });

    console.log(
      `  -> Created vendor "${v.name}" (riskScore=${score}) with ${subset.length} assessment(s).`
    );
  }

  const totalVendors = await prisma.vendor.count();
  const totalAssessments = await prisma.assessment.count();

  console.log("=== Demo seed complete ===");
  console.log(`Vendors: ${totalVendors}`);
  console.log(`Assessments: ${totalAssessments}`);
}

main()
  .catch((e) => {
    console.error("Demo seed failed:", e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
'@ | Set-Content -Path $seedFile -Encoding UTF8

Write-Host "[INFO] Demo seed script written." -ForegroundColor Green

# 2) Ensure Prisma client is generated
Write-Host "[STEP] Running 'pnpm exec prisma generate'..." -ForegroundColor Cyan
pnpm exec prisma generate

# 3) Run the demo seed
Write-Host "[STEP] Running Node demo seed (demo-seed.cjs)..." -ForegroundColor Cyan
node $seedFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Demo seed failed with exit code $LASTEXITCODE." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "[OK] Demo data seeded (or skipped if vendors already existed)." -ForegroundColor Green

# 4) Trigger cloud deploy so Board Report reflects new data
$deployScript = Join-Path $root "Phase132g-CloudDeploy.ps1"
if (Test-Path $deployScript) {
    Write-Host "[STEP] Running Phase132g-CloudDeploy.ps1..." -ForegroundColor Cyan
    & $deployScript
} else {
    Write-Host "[STEP] Running 'vercel --prod --yes' (fallback)..." -ForegroundColor Cyan
    vercel --prod --yes
}

Write-Host "=== Phase135-SeedDemo complete ===" -ForegroundColor Cyan
