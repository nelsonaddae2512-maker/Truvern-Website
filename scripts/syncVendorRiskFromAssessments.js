// scripts/syncVendorRiskFromAssessments.js
/*
  Phase 309 — Vendor Health Sync From Assessments

  This script:
  - Groups assessments by vendorId
  - Calculates the AVG(score) for each vendor
  - Updates vendor.riskScore with the clamped average

  It only touches vendors that have at least one scored assessment.
*/

const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

function clampScore(value) {
  if (value == null || Number.isNaN(Number(value))) return null;
  const n = Number(value);
  if (n < 0) return 0;
  if (n > 100) return 100;
  return Math.round(n);
}

async function main() {
  console.log("▶ Computing vendor health from assessment scores…");

  // Group assessments by vendorId, only where score is set
  const grouped = await prisma.assessment.groupBy({
    by: ["vendorId"],
    _avg: {
      score: true,
    },
    where: {
      score: {
        not: null,
      },
      vendorId: {
        not: null,
      },
    },
  });

  console.log(`Found ${grouped.length} vendor(s) with scored assessments.\n`);

  let updatedCount = 0;

  for (const group of grouped) {
    const vendorId = group.vendorId;
    const avgScore = group._avg.score;

    if (vendorId == null || avgScore == null) continue;

    const clamped = clampScore(avgScore);

    await prisma.vendor.update({
      where: { id: vendorId },
      data: { riskScore: clamped },
    });

    updatedCount += 1;
    console.log(
      `✓ Vendor #${vendorId} → riskScore = ${clamped} (avg assessment score ${avgScore.toFixed(
        2
      )})`
    );
  }

  console.log(`\n✅ Sync complete. Updated ${updatedCount} vendor(s).`);
}

main()
  .catch((err) => {
    console.error("❌ Error during vendor risk sync:", err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
