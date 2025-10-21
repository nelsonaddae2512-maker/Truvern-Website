import prisma from "@/lib/db";

export const runtime = "nodejs"
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";import type { NextRequest } from "next/server";

/**
 * GET: return a benign payload or echo a requested evidenceId if provided.
 * This keeps build-time "collect page data" happy and avoids throwing.
 */
export async function GET(req: NextRequest){ const { prisma } = await import("@/lib/prisma"); 
  try {
    const url = new URL(req.url);
    const evidenceId = url.searchParams.get("evidenceId");
    return NextResponse.json({ ok: true, evidenceId: evidenceId || null }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}

/**
 * POST: (optional) generate an upload URL / mark intent.
 * Adjust to your storage needs later. Prisma is imported lazily.
 * Body: { filename?: string, contentType?: string, evidenceId?: string }
 */
export async function POST(req: NextRequest){ const { prisma } = await import("@/lib/prisma"); 
  try {
    const body = await req.json().catch(() => ({} as any));
    const filename = typeof body.filename === "string" ? body.filename : null;
    const contentType = typeof body.contentType === "string" ? body.contentType : null;
    const evidenceId = typeof body.evidenceId === "string" ? body.evidenceId : null;

    // Lazy import prisma only at request time (prevents build-time init)
    // If you donÃ¢â‚¬â„¢t need DB here yet, you can remove these two lines later.
    try {
      const mod = (await import("@/lib/prisma")) as { prisma?: any };
      if (mod?.prisma && evidenceId) {
        // Example: touch a row safely; wrap in try/catch to avoid hard failures.
        try {
          await mod.prisma.evidence.update({
            where: { id: evidenceId as any },
            data: { updatedAt: new Date() }
          });
        } catch { /* ignore db errors in this hardened route */ }
      }
    } catch { /* ignore lazy import errors */ }

    // Return a placeholder URL shape (wire real storage later)
    const dummyUrl = filename ? `about:blank#${encodeURIComponent(filename)}` : null;
    return NextResponse.json({ ok: true, uploadUrl: dummyUrl, contentType, evidenceId }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}

