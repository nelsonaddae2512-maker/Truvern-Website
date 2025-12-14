// scripts/backfillAssessmentScores.js
/* 
  One-time helper script to backfill Assessment.score
  using the vendor's riskScore when available.

  Run with:
    node scripts/backfillAssessmentScores.js
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
  console.log("▶ Fetching assessments without a score…");

  const assessments = await prisma.assessment.findMany({
    where: {
      score: null,
    },
    include: {
      vendor: {
        select: {
          id: true,
          name: true,
          riskScore: true,
        },
      },
    },
  });

  console.log(`Found ${assessments.length} assessment(s) with score = null.`);

  let updatedCount = 0;

  for (const a of assessments) {
    const vendor = a.vendor;

    // Prefer vendor.riskScore if present
    let proposedScore =
      vendor && typeof vendor.riskScore === "number"
        ? clampScore(vendor.riskScore)
        : null;

    // Fallback to a neutral default score if we still don't have one
    if (proposedScore == null) {
      proposedScore = 75; // safe "OK" default that you can tweak
    }

    await prisma.assessment.update({
      where: { id: a.id },
      data: { score: proposedScore },
    });

    updatedCount += 1;

    console.log(
      `✓ Assessment #${a.id} (${vendor?.name ?? "No vendor"}) → score = ${proposedScore}`
    );
  }

  console.log(`\n✅ Backfill complete. Updated ${updatedCount} assessment(s).`);
}

main()
  .catch((err) => {
    console.error("❌ Error during backfill:", err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
