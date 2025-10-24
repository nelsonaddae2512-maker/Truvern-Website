import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  const vendors = [
    {
      name: "AWS",
      website: "https://aws.amazon.com",
      logoUrl: "https://a0.awsstatic.com/libra-css/images/logos/aws_logo_smile_1200x630.png",
      description: "Cloud infrastructure & services",
      category: "cloud",
      trustScore: 95,
    },
    {
      name: "Google Cloud",
      website: "https://cloud.google.com",
      logoUrl: "https://cloud.google.com/_static/cloud/images/social-icon-google-cloud-1200-630.png",
      description: "Cloud platform & services",
      category: "cloud",
      trustScore: 92,
    },
    {
      name: "Microsoft",
      website: "https://www.microsoft.com",
      logoUrl: "https://seeklogo.com/images/M/microsoft-logo-4BA5F4AD3D-seeklogo.com.png",
      description: "Software & cloud services",
      category: "software",
      trustScore: 90,
    },
  ];

  for (const v of vendors) {
    await prisma.vendor.upsert({
      where: { name: v.name },
      update: {
        website: v.website ?? null,
        logoUrl: v.logoUrl ?? null,
        description: v.description ?? null,
        category: v.category ?? null,
        trustScore: v.trustScore ?? null,
      },
      create: {
        name: v.name,
        website: v.website ?? null,
        logoUrl: v.logoUrl ?? null,
        description: v.description ?? null,
        category: v.category ?? null,
        trustScore: v.trustScore ?? null,
      },
    });
  }

  const org = await prisma.organization.upsert({
    where: { name: "Default Organization" },
    update: { plan: "free", seats: 5 },
    create: { name: "Default Organization", plan: "free", seats: 5 },
  });

  await prisma.evidence.createMany({
    data: [
      {
        userId: "demo-user-1",
        vendor: "AWS",
        filename: "soc2-report.pdf",
        url: "https://example.com/soc2-report.pdf",
        size: 1024,
        note: "Most recent SOC 2 report",
      },
      {
        userId: "demo-user-1",
        vendor: "Microsoft",
        filename: "iso27001-certificate.pdf",
        url: "https://example.com/iso27001.pdf",
        size: 2048,
        note: "ISO 27001 cert",
      },
    ],
    skipDuplicates: true,
  });

  await prisma.usage.createMany({
    data: [
      { organizationId: org.id, description: "Initial login" },
      { organizationId: org.id, description: "Uploaded vendor evidences" },
    ],
    skipDuplicates: true,
  });

  await prisma.assessmentSubmission.createMany({
    data: [
      {
        companyName: "Truvern Test Co",
        contactEmail: "admin@truvern.test",
        answersJson: { q1: "Yes", q2: "No", score: 7 },
      },
    ],
    skipDuplicates: true,
  });

  console.log("✅ Prisma seed complete.");
}

main()
  .then(async () => await prisma.$disconnect())
  .catch(async (e) => {
    console.error("❌ Seed failed:", e);
    await prisma.$disconnect();
    process.exit(1);
  });