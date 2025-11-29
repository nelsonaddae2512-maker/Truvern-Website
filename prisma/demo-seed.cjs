/**
 * Demo seed script for Truvern
 * - Populates ~20 vendors with realistic risk scores
 * - Adds 1â€“4 assessments per vendor over the last 18 months
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

    // Randomly decide whether to include all 3 or just 1â€“2
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
