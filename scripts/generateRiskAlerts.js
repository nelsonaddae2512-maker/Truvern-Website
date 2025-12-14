// scripts/generateRiskAlerts.js
// Phase 320 – Automated Risk Alerts
//
// Rules implemented:
// 1) DECLINING_CRITICAL_TREND
//    - 30d trend = DECLINING and tier = CRITICAL or HIGH
// 2) WEAK_WITHOUT_EVIDENCE
//    - riskScore < 50 and evidence count = 0
// 3) UNASSESSED_30D_OLD
//    - vendor created > 30 days ago and assessments count = 0

const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  console.log("Phase 320 – Generating automated risk alerts…");

  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

  const vendors = await prisma.vendor.findMany({
    include: {
      _count: {
        select: {
          assessments: true,
          evidence: true,
        },
      },
      riskAlerts: {
        where: {
          resolvedAt: null,
        },
      },
    },
  });

  console.log(`Loaded ${vendors.length} vendors.`);

  for (const v of vendors) {
    const openAlerts = v.riskAlerts;
    const desiredAlertTypes = new Set();

    const tier = (v.tier ?? "").toUpperCase();
    const trend30 = (v.riskTrend30d ?? "").toUpperCase();
    const riskScore = v.riskScore ?? null;
    const hasAssessments = v._count.assessments > 0;
    const hasEvidence = v._count.evidence > 0;

    // Rule 1: Declining trend for critical/high vendors
    if (
      (tier === "CRITICAL" || tier === "HIGH") &&
      trend30 === "DECLINING"
    ) {
      desiredAlertTypes.add("DECLINING_CRITICAL_TREND");
    }

    // Rule 2: Weak risk score without evidence
    if (riskScore !== null && riskScore < 50 && !hasEvidence) {
      desiredAlertTypes.add("WEAK_WITHOUT_EVIDENCE");
    }

    // Rule 3: 30+ days old with no assessments
    if (v.createdAt < thirtyDaysAgo && !hasAssessments) {
      desiredAlertTypes.add("UNASSESSED_30D_OLD");
    }

    // Resolve alerts that are no longer relevant
    for (const alert of openAlerts) {
      if (!desiredAlertTypes.has(alert.type)) {
        await prisma.vendorRiskAlert.update({
          where: { id: alert.id },
          data: { resolvedAt: now },
        });
        console.log(
          `Resolved alert ${alert.id} (type ${alert.type}) for vendor ${v.id}`
        );
      }
    }

    // Create alerts that should exist but don't
    const openTypes = new Set(openAlerts.map((a) => a.type));

    for (const type of desiredAlertTypes) {
      if (!openTypes.has(type)) {
        const message = buildAlertMessage(type, v);
        await prisma.vendorRiskAlert.create({
          data: {
            vendorId: v.id,
            type,
            message,
          },
        });
        console.log(
          `Created alert ${type} for vendor ${v.id} (${v.name})`
        );
      }
    }
  }

  console.log("Risk alerts generation complete.");
}

function buildAlertMessage(type, vendor) {
  const name = vendor.name;
  const riskScore =
    vendor.riskScore == null ? "Unknown" : `${vendor.riskScore}/100`;
  const tier = (vendor.tier ?? "Unspecified").toString();

  switch (type) {
    case "DECLINING_CRITICAL_TREND":
      return `${name} (${tier}) shows a declining 30-day risk trend. Current score: ${riskScore}. Consider closer review.`;
    case "WEAK_WITHOUT_EVIDENCE":
      return `${name} has a weak risk score (${riskScore}) with no evidence uploaded. Request certifications or reports.`;
    case "UNASSESSED_30D_OLD":
      return `${name} has been onboarded for more than 30 days with no assessments completed. Trigger an initial assessment.`;
    default:
      return `${name} triggered risk alert type ${type}.`;
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
