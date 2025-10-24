const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
(async () => {
  const url = new URL(process.env.DATABASE_URL);
  console.log("DB Host:", url.hostname);
  const cols = await prisma.$queryRawUnsafe("SELECT column_name FROM information_schema.columns WHERE table_name = 'vendor' ORDER BY ordinal_position;");
  console.log("Vendor columns:", cols.map(c => c.column_name));
  const count = await prisma.vendor.count();
  console.log("Vendor count:", count);
  const sample = await prisma.vendor.findMany({ take: 3 });
  console.log("Sample vendors:", sample);
  await prisma.$disconnect();
})();