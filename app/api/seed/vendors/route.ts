import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { getDbOrg } from "@/lib/db-org";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function slugify(input: string) {
  return input
    .toLowerCase()
    .trim()
    .replace(/['"]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
}

async function runSeed() {
  const org = await getDbOrg();
  if (!org) return NextResponse.json({ ok: false, error: "No org" }, { status: 401 });

  const seed = [
    { name: "Acme Payments", category: "Payments", tier: "IMPORTANT", criticality: "HIGH", riskScore: 78 },
    { name: "Northwind Cloud", category: "Cloud", tier: "CRITICAL", criticality: "HIGH", riskScore: 62 },
    { name: "Contoso HRIS", category: "HR", tier: "STANDARD", criticality: "MEDIUM", riskScore: 84 },
    { name: "Fabrikam Analytics", category: "Analytics", tier: "IMPORTANT", criticality: "MEDIUM", riskScore: 73 },
  ] as const;

  const created: any[] = [];

  for (const v of seed) {
    const baseSlug = slugify(v.name) || "vendor";
    let slug = baseSlug;
    for (let i = 0; i < 50; i++) {
      const exists = await prisma.vendor.findFirst({ where: { slug } });
      if (!exists) break;
      slug = `${baseSlug}-${i + 2}`;
    }

    const row = await prisma.vendor.upsert({
      where: { organizationId_name: { organizationId: org.id, name: v.name } },
      update: {
        category: v.category,
        tier: v.tier as any,
        criticality: v.criticality as any,
        riskScore: v.riskScore,
        status: "Active",
      },
      create: {
        organizationId: org.id,
        name: v.name,
        slug,
        category: v.category,
        tier: v.tier as any,
        criticality: v.criticality as any,
        riskScore: v.riskScore,
        status: "Active",
        summary: "Demo vendor seeded by Truvern.",
      },
    });

    created.push({ id: row.id, name: row.name, slug: row.slug });
  }

  return NextResponse.json({ ok: true, organization: { id: org.id, slug: org.slug }, created });
}

export async function POST() {
  return runSeed();
}

// ✅ allow seeding by just opening the URL in your signed-in browser
export async function GET() {
  return runSeed();
}
