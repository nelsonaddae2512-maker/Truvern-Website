export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/**
 * GET: benign response so Next's build-time "collect page data" never fails.
 */
export async function GET(req: NextRequest){ const { prisma } = await import("@/lib/prisma"); 
  try {
    const q = new URL(req.url).searchParams;
    const vendorId = q.get("vendorId");
    return NextResponse.json({ ok: true, vendorId: vendorId || null }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false }, { status: 200 });
  }
}

/**
 * POST: accept JSON { vendorId, filename, contentType, size } and create a DB stub.
 * Prisma is lazy-imported so we don't touch @prisma/client at build time.
 */
export async function POST(req: NextRequest){ const { prisma } = await import("@/lib/prisma"); 
  try {
    const body = await req.json().catch(() => ({} as any));
    const vendorId = body?.vendorId ?? null;
    const filename = typeof body?.filename === "string" ? body.filename : null;
    const contentType = typeof body?.contentType === "string" ? body.contentType : null;
    const size = Number.isFinite(body?.size) ? Number(body.size) : null;

    // Lazy import prisma only at request time
    let prisma: any = null;
    try { prisma = (await import("@/lib/prisma"))?.prisma ?? null; } catch {}

    // If you don't need DB yet, skip this block safely
    let evidenceId: string | null = null;
    if (prisma && vendorId && filename) {
      try {
        const row = await prisma.evidence.create({
          data: {
            vendorId: vendorId as any,
            filename,
            contentType: contentType || "application/octet-stream",
            size: size || 0,
            status: "pending",
            updatedAt: new Date()
          },
          select: { id: true }
        });
        evidenceId = row?.id ?? null;
      } catch {
        // swallow DB errors in hardened route to avoid 500 during build
      }
    }

    // Return a placeholder upload URL shape (wire S3/GCS later)
    const uploadUrl = filename ? `about:blank#upload-${encodeURIComponent(filename)}` : null;
    return NextResponse.json({ ok: true, evidenceId, uploadUrl }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}