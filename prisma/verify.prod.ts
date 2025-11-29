import "dotenv/config";
import { PrismaClient } from "@prisma/client";
const prisma = new PrismaClient();

async function verify() {
  const vendors = await prisma.vendor.findMany({
    orderBy: { id: "asc" },
    include: { assessments: { orderBy: { id: "asc" } } }
  });

  console.log("✅ Vendors in production (with assessments):");
  console.log(JSON.stringify(vendors, null, 2));

  const vCount = await prisma.vendor.count();
  const aCount = await prisma.assessment.count();
  console.log(`\nSummary: ${vCount} vendor(s), ${aCount} assessment(s).`);

  await prisma.$disconnect();
}

verify().catch(async (e) => {
  console.error("❌ Verify failed:", e);
  await prisma.$disconnect();
  process.exit(1);
});