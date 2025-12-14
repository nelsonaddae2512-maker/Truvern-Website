// scripts/syncVendorRiskTrends.js
// Phase 318 – Risk Trends Engine
//
// 1. For each vendor, store a VendorRiskSnapshot with the current riskScore.
// 2. Compute 30d and 90d trend labels and store on Vendor.riskTrend30d / riskTrend90d.

const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function computeTrendLabel(latest, past) {
  if (latest == null || past == null) return "NEW";

  const diff = latest - past; // higher score = healthier
  const pct =
    past === 0 ? (diff === 0 ? 0 : 100) : (diff / Math.abs(past)) * 100;

  // Tune thresholds as needed
  if (pct >= 5) return "IMPROVING";
  if (pct <= -5) return "DECLINING";
  return "STABLE";
}

async function main() {
  console.log("Phase 318 – Sync vendor risk trends…");

  const vendors = await prisma.vendor.findMany({
    select: {
      id: true,
      riskScore: true,
    },
  });

  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

  console.log(`Found ${vendors.length} vendors.`);

  for (const vendor of vendors) {
    // 1) Insert a snapshot for today
    await prisma.vendorRiskSnapshot.create({
      data: {
        vendorId: vendor.id,
        score: vendor.riskScore ?? null,
      },
    });

    // 2) Pull snapshots for this vendor
    const snapshots = await prisma.vendorRiskSnapshot.findMany({
      where: { vendorId: vendor.id },
      orderBy: { takenAt: "asc" },
    });

    if (snapshots.length === 0) continue;

    const latest = snapshots[snapshots.length - 1];
    const latestScore = latest.score ?? null;

    // Helper to find the earliest snapshot inside a window
    function earliestInWindow(since) {
      return snapshots.find((s) => s.takenAt >= since) ?? null;
    }

    const earliest30 = earliestInWindow(thirtyDaysAgo);
    const earliest90 = earliestInWindow(ninetyDaysAgo);

    const past30 = earliest30 ? earliest30.score ?? null : null;
    const past90 = earliest90 ? earliest90.score ?? null : null;

    const trend30 = computeTrendLabel(latestScore, past30);
    const trend90 = computeTrendLabel(latestScore, past90);

    await prisma.vendor.update({
      where: { id: vendor.id },
      data: {
        riskTrend30d: trend30,
        riskTrend90d: trend90,
      },
    });

    console.log(
      `Vendor ${vendor.id}: latest=${latestScore}, 30d=${trend30}, 90d=${trend90}`
    );
  }

  console.log("Done syncing risk trends.");
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
