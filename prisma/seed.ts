import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const org = await prisma.organization.create({
    data: {
      name: "Truvern Demo Org",
      slug: "truvern-demo",
    },
  });

  const vendor = await prisma.vendor.create({
    data: {
      name: "Acme Security",
      slug: "acme-security",
      organizationId: org.id,
    },
  });

  const issue = await prisma.issue.create({
    data: {
      title: "SOC 2 Type II report missing",
      description: "Vendor has not provided an up-to-date SOC 2 Type II report.",
      severity: "HIGH",
      status: "OPEN",
      organizationId: org.id,
      vendorId: vendor.id,
      dueAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
    },
  });

  await prisma.issueEvent.create({
    data: {
      issueId: issue.id,
      type: "CREATED",
      payload: { source: "seed" },
    },
  });

  console.log("✅ Seed complete");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
