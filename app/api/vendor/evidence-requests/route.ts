// app/api/vendor/evidence-requests/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

async function resolveVendorId() {
  if (devBypassEnabled()) {
    const v = Number(process.env.TRUVERN_DEV_VENDOR_ID ?? "");
    return Number.isFinite(v) ? v : null;
  }

  const { userId } = auth();
  if (!userId) return null;

  const user = await currentUser();
  const vendorIdRaw = (user?.publicMetadata as any)?.vendorId;

  const vendorId =
    typeof vendorIdRaw === "number"
      ? vendorIdRaw
      : typeof vendorIdRaw === "string"
      ? Number(vendorIdRaw)
      : NaN;

  return Number.isFinite(vendorId) ? vendorId : null;
}

export async function GET() {
  try {
    const vendorId = await resolveVendorId();
    if (!vendorId) {
      return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
    }

    // ✅ Archived vendor guardrail (Vendor Portal should not surface tasks for archived vendors)
    const vendor = await prisma.vendor.findUnique({
      where: { id: vendorId },
      select: { id: true, deletedAt: true },
    });

    if (!vendor) {
      return NextResponse.json({ ok: false, error: "Vendor not found" }, { status: 404 });
    }

    if (vendor.deletedAt) {
      return NextResponse.json(
        {
          ok: false,
          error: "Vendor is archived. Restore to view and complete evidence requests.",
          vendorId,
          requests: [],
        },
        { status: 409 }
      );
    }

    const requests = await prisma.evidenceRequest.findMany({
      where: {
        vendorId,
        status: { in: ["OPEN", "REJECTED"] } as any,
      },
      orderBy: [{ dueAt: "asc" as any }, { createdAt: "desc" as any }],
      take: 50,
      select: {
        id: true,
        kind: true,
        label: true,
        description: true,
        dueAt: true,
        status: true,
        createdAt: true,
        updatedAt: true,
      },
    });

    return NextResponse.json({ ok: true, vendorId, requests });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Failed to load evidence requests" },
      { status: 500 }
    );
  }
}
