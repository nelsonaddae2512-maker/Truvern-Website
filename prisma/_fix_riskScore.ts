import "dotenv/config";

// Dynamic import for Node 24 ESM
const { PrismaClient } = await import("@prisma/client");
const prisma = new PrismaClient();

async function ensureRiskScore() {
  // Check both "Vendor" (quoted) and vendor (unquoted) just in case
  const rows = await prisma.$queryRawUnsafe(`
    SELECT column_name, data_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name = 'riskScore'
      AND table_name IN ('Vendor','vendor')
    LIMIT 1;
  `);

  if (Array.isArray(rows) && rows.length > 0) {
    const r = rows[0] as any;
    console.log(`[i] Column already exists (data_type=${r.data_type}). No change needed.`);
    return "exists";
  }

  // Create column safely (INTEGER DEFAULT 0). Use quoted "Vendor" to match Prisma's default mapping.
  await prisma.$executeRawUnsafe(`ALTER TABLE "Vendor" ADD COLUMN "riskScore" INTEGER DEFAULT 0;`);
  console.log(`[+] Added column "riskScore" (INTEGER DEFAULT 0) to table "Vendor".`);
  return "added";
}

(async () => {
  try {
    // Prove connectivity first
    await prisma.$queryRaw`SELECT 1`;
    const status = await ensureRiskScore();
    console.log(`[✓] ensureRiskScore: ${status}`);
  } catch (e) {
    console.error("❌ Fix script failed:", e);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
})();
