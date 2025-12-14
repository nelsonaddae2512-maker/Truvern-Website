// scripts/backfillAssessmentCIA.js
/*
  Phase 312 — CIA Backfill Script

  Fills confidentialityScore, integrityScore, and availabilityScore
  for assessments where at least one of those is null.

  Logic:
  - Use assessment.score as the base when available
  - Add small variations per dimension for realistic data
  - Clamp everything to 0–100
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

function randomOffset(range) {
  // returns integer in [-range, range]
  const r = Math.random() * (range * 2) - range;
  return Math.round(r);
}

async function main() {
  console.log("▶ Fetching assessments needing CIA backfill…");

  const assessments = await prisma.assessment.findMany({
    where: {
      OR: [
        { confidentialityScore: null },
        { integrityScore: null },
        { availabilityScore: null }
      ]
    },
    orderBy: { createdAt: "desc" }
  });

  console.log(`Found ${assessments.length} assessment(s) missing CIA scores.\n`);

  let updatedCount = 0;

  for (const a of assessments) {
    const baseScore =
      typeof a.score === "number" && !Number.isNaN(a.score)
        ? a.score
        : 75; // neutral default if score is missing

    // Small, slightly biased variations
    const cRaw = baseScore + randomOffset(5);  // confidentiality around base
    const iRaw = baseScore + randomOffset(7);  // integrity a bit more varied
    const aRaw = baseScore + randomOffset(9);  // availability most volatile

    const confidentialityScore = clampScore(
      a.confidentialityScore ?? cRaw
    );
    const integrityScore = clampScore(
      a.integrityScore ?? iRaw
    );
    const availabilityScore = clampScore(
      a.availabilityScore ?? aRaw
    );

    await prisma.assessment.update({
      where: { id: a.id },
      data: {
        confidentialityScore,
        integrityScore,
        availabilityScore
      }
    });

    updatedCount += 1;
    console.log(
      `✓ Assessment #${a.id} → C=${confidentialityScore}, I=${integrityScore}, A=${availabilityScore} (base score ${baseScore})`
    );
  }

  console.log(`\n✅ CIA backfill complete. Updated ${updatedCount} assessment(s).`);
}

main()
  .catch((err) => {
    console.error("❌ Error during CIA backfill:", err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
