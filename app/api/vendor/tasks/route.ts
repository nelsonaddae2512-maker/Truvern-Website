import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { auth, currentUser } from "@clerk/nextjs/server";

export const runtime = "nodejs";

function toISO(d: Date | string | null | undefined) {
  if (!d) return null;
  const date = typeof d === "string" ? new Date(d) : d;
  return date.toISOString();
}

function devBypassEnabled() {
  return (
    process.env.NODE_ENV !== "production" &&
    process.env.TRUVERN_DEV_BYPASS_AUTH === "1"
  );
}

export async function GET(req: Request) {
  try {
    const url = new URL(req.url);

    // ✅ DEV bypass (OFF by default; blocked in production)
    if (devBypassEnabled()) {
      const fromQuery = url.searchParams.get("vendorId");
      const envVendorId = process.env.TRUVERN_DEV_VENDOR_ID;

      const vendorId = Number(fromQuery ?? envVendorId ?? "");
      if (!Number.isFinite(vendorId)) {
        return NextResponse.json(
          {
            ok: false,
            error:
              "DEV bypass enabled, but no vendorId provided. Set TRUVERN_DEV_VENDOR_ID or pass ?vendorId=123",
          },
          { status: 400 }
        );
      }

      const assessments = await prisma.assessment.findMany({
        where: { vendorId },
        orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
        take: 50,
        select: {
          id: true,
          title: true,
          status: true,
          updatedAt: true,
          template: { select: { id: true, name: true } },
        },
      });

      return NextResponse.json({
        ok: true,
        devBypass: true,
        vendorId,
        tasks: {
          assessments: assessments.map((a) => ({
            id: a.id,
            title: a.title ?? a.template?.name ?? `Run #${a.id}`,
            status: a.status ?? "—",
            updatedAt: toISO(a.updatedAt),
            dueAt: null,
          })),
          evidenceRequests: [],
        },
      });
    }

    // ✅ Normal behavior (production-ready)
    const { userId } = auth();
    if (!userId) {
      return NextResponse.json(
        { ok: false, error: "Unauthorized" },
        { status: 401 }
      );
    }

    const user = await currentUser();
    const vendorIdRaw = (user?.publicMetadata as any)?.vendorId;
    const vendorId =
      typeof vendorIdRaw === "number"
        ? vendorIdRaw
        : typeof vendorIdRaw === "string"
        ? Number(vendorIdRaw)
        : undefined;

    if (!Number.isFinite(vendorId as any)) {
      return NextResponse.json(
        { ok: false, error: "Vendor account not linked (missing vendorId)." },
        { status: 403 }
      );
    }

    const assessments = await prisma.assessment.findMany({
      where: { vendorId: vendorId as number },
      orderBy: [{ updatedAt: "desc" }, { id: "desc" }],
      take: 50,
      select: {
        id: true,
        title: true,
        status: true,
        updatedAt: true,
        template: { select: { id: true, name: true } },
      },
    });

    return NextResponse.json({
      ok: true,
      tasks: {
        assessments: assessments.map((a) => ({
          id: a.id,
          title: a.title ?? a.template?.name ?? `Run #${a.id}`,
          status: a.status ?? "—",
          updatedAt: toISO(a.updatedAt),
          dueAt: null,
        })),
        evidenceRequests: [],
      },
    });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message ?? "Failed to load vendor tasks" },
      { status: 500 }
    );
  }
}
