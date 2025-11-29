// scripts/seed-vendors.ts
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  console.log("🌱 Seeding vendors into Neon database...");

  const vendors = [
    {
      name: "Default Vendor",
      riskScore: 0,
    },
    {
      name: "CloudCore Infrastructure",
      riskScore: 72,
    },
    {
      name: "Atlas Identity Services",
      riskScore: 64,
    },
    {
      name: "Northwind Logistics",
      riskScore: 55,
    },
    {
      name: "Beacon Payments",
      riskScore: 81,
    },
    {
      name: "BlueSky Analytics",
      riskScore: 43,
    },
  ];

  for (const v of vendors) {
    await prisma.vendor.upsert({
      where: { name: v.name },       // name is @unique in your schema
      update: {
        riskScore: v.riskScore,
      },
      create: {
        name: v.name,
        riskScore: v.riskScore,
        // createdAt will use the default(now())
      },
    });

    console.log(`  ✔ Upserted vendor: ${v.name}`);
  }

  console.log("✅ Vendor seed complete.");
}

main()
  .catch((e) => {
    console.error("❌ Error seeding vendors:", e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
