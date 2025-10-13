const { PrismaClient } = require("@prisma/client");
const prisma = new PrismaClient();
async function safe(upserter){
  try{ return await upserter(); }catch(e){ console.log("seed note:", e.message); }
}
(async ()=>{
  // Adjust names/fields to match your schema if needed
  const org = await safe(()=>prisma.organization.upsert({
    where: { name: "Demo Org" },
    update: {},
    create: { name: "Demo Org", plan: "pro", seats: 10 }
  }));

  const user = await safe(()=>prisma.user.upsert({
    where: { email: "demo@demo.com" },
    update: {},
    create: { email: "demo@demo.com", name: "Demo User" }
  }));

  if (org && user) {
    await safe(()=>prisma.membership.upsert({
      where: { userId_organizationId: { userId: user.id, organizationId: org.id } },
      update: {},
      create: { userId: user.id, organizationId: org.id, role: "ADMIN" }
    }));
  }

  await safe(()=>prisma.vendor.upsert({
    where: { slug: "demo-vendor" },
    update: {},
    create: { name: "Demo Vendor", slug: "demo-vendor", ownerId: user?.id }
  }));

  console.log("✅ Seed complete");
  await prisma.$disconnect();
})();