const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function run() {
  console.log("Connecting to DB...");
  try {
    const url = new URL(process.env.DATABASE_URL);
    console.log("DB Host:", url.hostname);

    // Show vendor table columns
    const cols = await prisma.$queryRawUnsafe(
      "SELECT column_name FROM information_schema.columns WHERE table_name = 'vendor' ORDER BY ordinal_position;"
    );
    const colNames = cols.map(c => c.column_name);
    console.log("Vendor columns:", colNames);

    // Count vendors
    const count = await prisma.vendor.count();
    console.log("Vendor count:", count);

    // Sample rows
    const sample = await prisma.vendor.findMany({ take: 5 });
    console.log("Sample vendors:", sample);
  } catch (err) {
    console.error("❌ Error:", err);
  } finally {
    await prisma.$disconnect();
    process.exit();
  }
}

run();
