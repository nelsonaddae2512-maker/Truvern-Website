export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

type AnswerLite = { frameworks?: string[]; evidenceStatus?: "approved"|"pending"|"rejected"|string|null };

export async function GET(req: NextRequest, ctx: { params: { slug?: string } }) {
  try {
    const slug = String(ctx?.params?.slug || "").trim().toLowerCase();
    if (!slug) return NextResponse.json({ ok:false, error:"missing_slug" }, { status:200 });

    const mod = (await import("@/lib/prisma")) as { prisma?: any };
    const prisma = mod?.prisma;
    if (!prisma) return NextResponse.json({ ok:false, error:"prisma_unavailable" }, { status:200 });

    const vendor = await prisma.vendor.findFirst({ where: { slug }, select: { id:true, name:true, slug:true, trustScore:true, trustLevel:true } });
    if (!vendor) return NextResponse.json({ ok:false, error:"not_found" }, { status:200 });

    let score = typeof vendor.trustScore === "number" ? vendor.trustScore : 0;
    let level = typeof vendor.trustLevel === "string" ? vendor.trustLevel : "Low";

    if (vendor.trustScore == null || !vendor.trustLevel) {
      const answers: AnswerLite[] = await prisma.answer.findMany({
        where: { vendorId: vendor.id },
        select: { frameworks: true, evidenceStatus: true }
      });
      const total = answers.length;
      const approved = answers.filter((a: AnswerLite) => a.evidenceStatus === "approved").length;
      score = total > 0 ? Math.round((approved / total) * 100) : 0;
      level = score >= 80 ? "High" : score >= 50 ? "Medium" : "Low";
      try {
        await prisma.vendor.update({ where: { id: vendor.id }, data: { trustScore: score, trustLevel: level, trustUpdatedAt: new Date() } });
      } catch {}
    }

    const fw = new Set<string>();
    const a2: AnswerLite[] = await prisma.answer.findMany({ where: { vendorId: vendor.id }, select: { frameworks: true } });
    a2.forEach((x: AnswerLite) => (x.frameworks ?? []).forEach((f: string) => fw.add(f)));

    return NextResponse.json({
      ok: true,
      vendor: { name: vendor.name, slug: vendor.slug },
      trust: { score, level, updatedAt: new Date().toISOString() },
      stats: { answers: a2.length, frameworks: Array.from(fw).slice(0, 12) }
    }, { status: 200 });
  } catch {
    return NextResponse.json({ ok:false, error:"internal" }, { status:200 });
  }
}