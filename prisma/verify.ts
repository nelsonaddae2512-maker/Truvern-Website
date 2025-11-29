import "dotenv/config";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function verify() {
  await prisma.$connect();

  const vendors = await prisma.vendor.findMany({
    orderBy: { id: "asc" },
    include: { assessments: { orderBy: { id: "asc" } } }
  });

  if (vendors.length === 0) {
    console.log("⚠️  No vendors found.");
  } else {
    console.log("✅ Vendors in DB (with assessments):");
    console.log(JSON.stringify(vendors, null, 2));
  }

  await prisma.$disconnect();
}

verify().catch(async (e) => {
  console.error("❌ Verify failed:", e);
  await prisma.$disconnect();
  process.exit(1);
});
