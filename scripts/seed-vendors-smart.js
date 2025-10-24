const { PrismaClient } = require("@prisma/client");
const crypto = require("crypto");
const prisma = new PrismaClient();

function valueFor(col) {
  const t = col.data_type;
  const name = col.column_name;
  if (name === "id" && (t.includes("uuid") || name.endsWith("Id"))) return crypto.randomUUID();
  if (t.includes("int")) return 90;
  if (t.includes("numeric") || t.includes("double") || t.includes("real")) return 90;
  if (t.includes("bool")) return true;
  if (t.includes("timestamp") || t.includes("date")) return new Date();
  if (t.includes("json")) return {};
  // strings
  if (name === "name") return "Truvern Labs";
  if (name === "slug") return "truvern-labs";
  if (name === "website" || name === "url") return "https://example.com";
  if (name === "category") return "Risk Intelligence";
  if (name.toLowerCase().includes("desc")) return "Seeded by script";
  if (name.toLowerCase().includes("status")) return "active";
  if (name.toLowerCase().includes("score")) return 92;
  return "seed";
}

async function main() {
  const url = new URL(process.env.DATABASE_URL);
  console.log("DB Host:", url.hostname);

  // Check that table exists and get columns
  const cols = await prisma.$queryRawUnsafe(`
    SELECT column_name, is_nullable, data_type, column_default
    FROM information_schema.columns
    WHERE table_name = 'vendor'
    ORDER BY ordinal_position
  `);

  if (!cols.length) {
    console.log("⚠️  No 'vendor' table found. Run 'prisma db push' again.");
    return;
  }

  // Build rows that include ONLY existing columns and satisfy NOT NULL w/out default
  const required = cols.filter(c => c.is_nullable === "NO" && !c.column_default);
  const existingNames = cols.map(c => c.column_name);

  const baseRow = {};
  for (const c of required) baseRow[c.column_name] = valueFor(c);

  // Add common optional fields if they exist
  function pickExtras(base) {
    const row = { ...base };
    const setIf = (n, v) => { if (existingNames.includes(n)) row[n] = v; };
    setIf("name", "Truvern Labs");
    setIf("slug", "truvern-labs");
    setIf("category", "Risk Intelligence");
    setIf("trustScore", 94);
    setIf("website", "https://truvern.com");
    setIf("description", "Trusted vendor for security and compliance automation.");
    setIf("published", true);
    setIf("isPublished", true);
    setIf("active", true);
    setIf("status", "active");
    setIf("approvedAt", new Date());
    return row;
  }

  const rows = [
    pickExtras(baseRow),
    pickExtras({ ...baseRow, name: "Acme Assurance", slug: "acme-assurance", trustScore: 90 }),
    pickExtras({ ...baseRow, name: "BlueShield Co.", slug: "blueshield-co", trustScore: 88 }),
  ];

  // Filter out any keys that are not actual columns (safety)
  const filtered = rows.map(r => Object.fromEntries(Object.entries(r).filter(([k]) => existingNames.includes(k))));

  // Insert
  const before = await prisma.vendor.count().catch(()=>0);
  await prisma.vendor.createMany({ data: filtered, skipDuplicates: true }).catch(async (e) => {
    console.log("createMany failed, trying individual inserts...", e.message);
    for (const r of filtered) {
      try { await prisma.vendor.create({ data: r }); } catch (e2) { console.log("single insert failed:", e2.message); }
    }
  });
  const after = await prisma.vendor.count().catch(()=>0);

  console.log("Vendor columns:", existingNames);
  console.log(`Count before: ${before}  after: ${after}`);
  const sample = await prisma.vendor.findMany({ take: 5 }).catch(()=>[]);
  console.log("Sample vendors:", sample);
}

main().finally(() => prisma.$disconnect());
