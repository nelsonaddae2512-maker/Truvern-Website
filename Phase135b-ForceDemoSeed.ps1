$ErrorActionPreference = "Stop"

Write-Host "=== Phase135b: FORCE demo vendors + assessments (upsert) ===" -ForegroundColor Cyan

$root = $PSScriptRoot
Set-Location $root
Write-Host "[INFO] Working in: $root" -ForegroundColor DarkCyan

$prismaDir = Join-Path $root "prisma"
if (-not (Test-Path $prismaDir)) {
    New-Item -ItemType Directory -Path $prismaDir | Out-Null
    Write-Host "[INFO] Created prisma directory." -ForegroundColor Yellow
}

$seedFile = Join-Path $prismaDir "demo-seed-force.cjs"

Write-Host "[INFO] Writing FORCE demo seed script to $seedFile" -ForegroundColor Cyan

@'
/**
 * FORCE demo seed for Truvern
 * - Upserts ~20 vendors by name (no duplicates)
 * - Adds 1–3 assessments per vendor over the last 18 months
 * - Safe to re-run multiple times
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
  console.log("=== Truvern FORCE demo seed starting ===");

  for (const v of demoVendors) {
    const score = v.riskScore;
    const level = riskLevelFromScore(score);

    const assessments = [
      { riskLevel: level, createdAt: monthsAgo(1) },
      { riskLevel: level, createdAt: monthsAgo(6) },
      { riskLevel: level, createdAt: monthsAgo(12) },
    ];

    const take = 1 + Math.floor(Math.random() * assessments.length);
    const subset = assessments.slice(0, take);

    const existing = await prisma.vendor.findUnique({
      where: { name: v.name },
      include: { assessments: true },
    });

    if (!existing) {
      // Create new vendor with assessments
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
    } else {
      // Update riskScore and ensure at least one recent assessment
      await prisma.vendor.update({
        where: { id: existing.id },
        data: { riskScore: score },
      });

      // Optionally add one fresh assessment
      await prisma.assessment.create({
        data: {
          vendorId: existing.id,
          riskLevel: level,
          createdAt: monthsAgo(0),
        },
      });

      console.log(
        `  -> Updated vendor "${v.name}" (riskScore=${score}) and added a fresh assessment.`
      );
    }
  }

  const totalVendors = await prisma.vendor.count();
  const totalAssessments = await prisma.assessment.count();

  console.log("=== FORCE demo seed complete ===");
  console.log(`Vendors in DB: ${totalVendors}`);
  console.log(`Assessments in DB: ${totalAssessments}`);
}

main()
  .catch((e) => {
    console.error("FORCE demo seed failed:", e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
'@ | Set-Content -Path $seedFile -Encoding UTF8

Write-Host "[INFO] FORCE demo seed script written." -ForegroundColor Green

# Ensure Prisma client is generated
Write-Host "[STEP] Running 'pnpm exec prisma generate'..." -ForegroundColor Cyan
pnpm exec prisma generate

# Run the FORCE demo seed
Write-Host "[STEP] Running Node demo seed (demo-seed-force.cjs)..." -ForegroundColor Cyan
node $seedFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] FORCE demo seed failed with exit code $LASTEXITCODE." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "[OK] FORCE demo data seeded / upserted." -ForegroundColor Green

# Trigger cloud deploy so UI reflects new data
$deployScript = Join-Path $root "Phase132g-CloudDeploy.ps1"
if (Test-Path $deployScript) {
    Write-Host "[STEP] Running Phase132g-CloudDeploy.ps1..." -ForegroundColor Cyan
    & $deployScript
} else {
    Write-Host "[STEP] Running 'vercel --prod --yes' (fallback)..." -ForegroundColor Cyan
    vercel --prod --yes
}

Write-Host "=== Phase135b-ForceDemoSeed complete ===" -ForegroundColor Cyan
