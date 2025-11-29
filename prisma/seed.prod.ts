import "dotenv/config";
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

async function main() {
  console.log("🌱 Starting Truvern production seed...");

  const vendor = await prisma.vendor.upsert({
    where: { name: "Default Vendor" },
    update: {},
    create: { name: "Default Vendor", riskScore: 30 }
  });

  const count = await prisma.assessment.count({ where: { vendorId: vendor.id } });
  if (count === 0) {
    await prisma.assessment.create({ data: { vendorId: vendor.id, riskLevel: "Low" } });
    console.log("➕ Created initial assessment for Default Vendor.");
  } else {
    console.log(`ℹ️  Skipped assessment creation (found ${count}).`);
  }

  console.log("✅ Seed complete.");
  await prisma.$disconnect();
}

main().catch(async (e) => {
  console.error("❌ Seed failed:", e);
  await prisma.$disconnect();
  process.exit(1);
});