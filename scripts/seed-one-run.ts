import prisma from "../lib/prisma";

const CLERK_ORG_ID = "org_375gF9XhJpNAZCcSTl7kvexpibg";

async function main() {
  const org = await prisma.organization.findFirst({
    where: { clerkOrgId: CLERK_ORG_ID },
    select: { id: true, slug: true, name: true },
  });

  if (!org) {
    throw new Error(`Organization not found for clerkOrgId=${CLERK_ORG_ID}`);
  }

  const run = await prisma.assessmentRun.create({
    data: {
      organizationId: org.id,
      status: "IN_PROGRESS",
      startedAt: new Date(),
    },
    select: {
      id: true,
      status: true,
      startedAt: true,
      organizationId: true,
    },
  });

  console.log("✅ Organization:", org);
  console.log("✅ Created AssessmentRun:", run);
  console.log(`➡ Open: http://localhost:3000/assessment/runs/${run.id}`);
}

main()
  .catch((err) => {
    console.error("❌ Seed failed:", err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
