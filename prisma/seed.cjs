/** prisma/seed.cjs (CommonJS) */
const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();

async function main() {
  console.log("Seeding start...");
  await prisma.$queryRaw`SELECT 1`;
  console.log("DB connection OK.");

  // List available Prisma model delegates (the model names)
  const delegates = Object.keys(prisma)
    .filter(k => !k.startsWith("$") && typeof prisma[k] === "object");
  console.log("Available Prisma delegates:", delegates);

  // We'll insert data once we confirm the correct model name + fields.
  console.log("Seed script finished (no writes yet).");
}

main()
  .then(() => prisma.$disconnect())
  .catch(async (e) => { console.error(e); await prisma.$disconnect(); process.exit(1); });
