export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/** Local helper types to avoid TS implicit-any */
type AnswerLite = { frameworks?: string[]; evidenceStatus?: "approved"|"pending"|"rejected"|string|null };

export async function GET(req: NextRequest, ctx: { params: { slug?: string } }) {
  try {
    const slug = String(ctx?.params?.slug || "").trim().toLowerCase();
    if (!slug) return NextResponse.json({ ok:false, error:"missing_slug" }, { status:200 });

    // Lazy-load Prisma at request-time only (prevents build-time init)
    const mod = (await import("@/lib/prisma")) as { prisma?: any };
    const prisma = mod?.prisma;
    if (!prisma) return NextResponse.json({ ok:false, error:"prisma_unavailable" }, { status:200 });

    const vendor = await prisma.vendor.findFirst({ where: { slug }, select: { id:true, name:true, slug:true } });
    if (!vendor) return NextResponse.json({ ok:false, error:"not_found" }, { status:200 });

    // Pull minimal data required to derive trust
    const answers: AnswerLite[] = await prisma.answer.findMany({
      where: { vendorId: vendor.id },
      select: { frameworks: true, evidenceStatus: true }
    });

    // Simple trust calculation (placeholder – replace with your real logic)
    const total = answers.length;
    let approved = 0, pending = 0;
    for (const a of answers) {
      if (a.evidenceStatus === "approved") approved++;
      else if (a.evidenceStatus === "pending") pending++;
    }
    const score = total > 0 ? Math.round((approved / total) * 100) : 0;
    const level = score >= 80 ? "High" : score >= 50 ? "Medium" : "Low";

    // Frameworks set without implicit-any
    const fwSet = new Set<string>();
    (answers as AnswerLite[]).forEach((a: AnswerLite) => {
      (a.frameworks ?? []).forEach((f: string) => fwSet.add(f));
    });

    // Persist computed trust (soft-fail)
    try {
      await prisma.vendor.update({
        where: { id: vendor.id },
        data: { trustScore: score, trustLevel: level, trustUpdatedAt: new Date() }
      });
    } catch { /* ignore persistence errors in hardened route */ }

    return NextResponse.json({
      ok: true,
      vendor: { name: vendor.name, slug: vendor.slug },
      trust: { score, level, updatedAt: new Date().toISOString() },
      stats: {
        answers: total,
        evidenceApproved: approved,
        evidencePending: pending,
        frameworks: Array.from(fwSet).slice(0, 12)
      }
    }, { status: 200 });

  } catch {
    // Never throw during Next's "collect page data"
    return NextResponse.json({ ok:false, error:"internal" }, { status:200 });
  }
}