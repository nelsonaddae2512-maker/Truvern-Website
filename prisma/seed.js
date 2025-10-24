const { PrismaClient } = require("@prisma/client");
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
  ];

  for (const v of vendors) {
    await prisma.vendor.upsert({
      where: { name: v.name },
      update: v,
      create: v,
    });
  }

  const org = await prisma.organization.upsert({
    where: { name: "Default Organization" },
    update: { plan: "free", seats: 5 },
    create: { name: "Default Organization", plan: "free", seats: 5 },
  });

  await prisma.assessmentSubmission.createMany({
    data: [
      {
        companyName: "Truvern Test Co",
        contactEmail: "admin@truvern.test",
        answersJson: { q1: "Yes", q2: "No", score: 7 },
        createdAt: new Date(),
      },
    ],
    skipDuplicates: true,
  });

  console.log("✅ Seed complete.");
}

main()
  .then(async () => { await prisma.$disconnect(); })
  .catch(async (e) => {
    console.error("❌ Seed failed:", e);
    await prisma.$disconnect();
    process.exit(1);
  });