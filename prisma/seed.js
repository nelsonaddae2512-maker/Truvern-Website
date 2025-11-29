// prisma/seed.js
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  await prisma.vendor.createMany({
    data: [
      { name: "Acme Payments", riskScore: 68 },
      { name: "Samsara IoT", riskScore: 72 },
      { name: "Geotab Fleet", riskScore: 80 },
      { name: "Stripe Services", riskScore: 55 },
    ],
    skipDuplicates: true,
  });

  console.log("🌱 Seeded vendors successfully");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
