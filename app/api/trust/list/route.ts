
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function GET(req: Request){
  const { searchParams } = new URL(req.url);
  const q = (searchParams.get("q") || "").trim().toLowerCase();
  const fw = (searchParams.get("framework") || "").trim();

  const vendors = await prisma.vendor.findMany({
    where: { trustPublic: true },
    orderBy: [{ trustLevel: "desc" as any }, { trustScore: "desc" as any }, { updatedAt: "desc" }],
    take: 200,
  });

  const result = [];
  for(const v of vendors){
    const answers = await prisma.answer.findMany({ where: { vendorId: v.id }, select: { frameworks: true } });
    const set = new Set<string>(); answers.forEach(a => (a.frameworks || []).forEach(f => set.add(f)));
    const frameworks = Array.from(set).sort().slice(0, 8);

    if (q && !v.name.toLowerCase().includes(q) && !v.slug.toLowerCase().includes(q)) continue;
    if (fw && !frameworks.includes(fw)) continue;

    result.push({ name: v.name, slug: v.slug, trustScore: v.trustScore, trustLevel: v.trustLevel, updatedAt: v.trustUpdatedAt || v.updatedAt, frameworks });
  }

  return NextResponse.json({ vendors: result });
}
