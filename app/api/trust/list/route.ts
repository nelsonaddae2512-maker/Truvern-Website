export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";

type AnswerLite = { frameworks?: string[] | null };
type VendorLite = { id: string; name: string; slug: string };

export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url);
    const q = (url.searchParams.get("q") || "").trim().toLowerCase();
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") || 20), 1), 100);

    // Lazy import prisma at request time (prevents build-time failures)
    const mod = (await import("@/lib/prisma")) as { prisma?: any };
    const prisma = mod?.prisma;

    if (!prisma) {
      // Build-safe fallback
      return NextResponse.json({ ok: true, items: [], total: 0 }, { status: 200 });
    }

    // Pull vendors (lightweight)
    const vendors: VendorLite[] = await prisma.vendor.findMany({
      select: { id: true, name: true, slug: true },
      orderBy: { updatedAt: "desc" },
      take: 500 // soft cap before client-side filtering below
    });

    const items: Array<{
      name: string;
      slug: string;
      frameworks: string[];
    }> = [];

    for (const v of vendors) {
      // Optional client-side search over name/slug
      if (q && !v.name.toLowerCase().includes(q) && !v.slug.toLowerCase().includes(q)) continue;

      // Collect frameworks for this vendor (minimal select)
      const answers: AnswerLite[] = await prisma.answer.findMany({
        where: { vendorId: v.id },
        select: { frameworks: true }
      });

      const set = new Set<string>();
      (answers as AnswerLite[]).forEach((a: AnswerLite) => {
        (a.frameworks ?? []).forEach((f: string) => set.add(f));
      });

      items.push({
        name: v.name,
        slug: v.slug,
        frameworks: Array.from(set).sort().slice(0, 8)
      });

      if (items.length >= limit) break;
    }

    return NextResponse.json({ ok: true, items, total: items.length }, { status: 200 });
  } catch {
    // Never crash collect-page-data
    return NextResponse.json({ ok: true, items: [], total: 0 }, { status: 200 });
  }
}