// app/api/evidence/export/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { resolveActor } from "@/lib/actor";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

function toInt(v: string | null): number | null {
  if (!v) return null;
  const n = Number.parseInt(v, 10);
  return Number.isFinite(n) ? n : null;
}

function csvEscape(value: any) {
  if (value == null) return "";
  const s = String(value);
  if (/[",\n\r]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function toCsv(rows: any[][]) {
  return rows.map((r) => r.map(csvEscape).join(",")).join("\n");
}

export async function GET(req: NextRequest) {
  try {
    const actor = await resolveActor(req, { allowVendorActor: true });
    if (!actor) {
      return NextResponse.json(
        { ok: false, error: "Unauthorized" },
        { status: 401 }
      );
    }

    // ✅ SAFEST: NextRequest already provides nextUrl with URLSearchParams
    const vendorIdParam = req.nextUrl.searchParams.get("vendorId");

    const where: any = { deletedAt: null };

    if (actor.mode === "vendor") {
      where.vendorId = actor.vendorId;
    } else {
      const requestedVendorId = vendorIdParam ? toInt(vendorIdParam) : null;
      if (vendorIdParam && requestedVendorId == null) {
        return NextResponse.json(
          { ok: false, error: "Invalid vendorId" },
          { status: 400 }
        );
      }

      const allowed = await prisma.vendor.findMany({
        where: { organizationId: actor.orgId },
        select: { id: true },
      });
      const allowedIds = allowed.map((v) => v.id);

      if (allowedIds.length === 0) {
        const csv = toCsv([
          [
            "vendorName",
            "vendorId",
            "evidenceId",
            "title",
            "kind",
            "uploadedAt",
            "fileUrl",
            "description",
          ],
        ]);
        return new NextResponse(csv, {
          status: 200,
          headers: {
            "content-type": "text/csv; charset=utf-8",
            "content-disposition": `attachment; filename="truvern-evidence.csv"`,
          },
        });
      }

      if (requestedVendorId != null) {
        if (!allowedIds.includes(requestedVendorId)) {
          return NextResponse.json(
            { ok: false, error: "Forbidden vendorId" },
            { status: 403 }
          );
        }
        where.vendorId = requestedVendorId;
      } else {
        where.vendorId = { in: allowedIds };
      }
    }

    const records = await (prisma as any).evidence.findMany({
      where,
      orderBy: { uploadedAt: "desc" },
      take: 5000,
      select: {
        id: true,
        vendorId: true,
        title: true,
        description: true,
        fileUrl: true,
        uploadedAt: true,
        kind: true,
      },
    });

    const vendorIds = Array.from(
      new Set(
        records
          .map((e: any) => e.vendorId)
          .filter((x: any) => Number.isFinite(x))
      )
    ) as number[];

    const vendorRows =
      vendorIds.length > 0
        ? await prisma.vendor.findMany({
            where: { id: { in: vendorIds } },
            select: { id: true, name: true },
          })
        : [];

    const vendorNameById = new Map<number, string>(
      vendorRows.map((v) => [v.id, v.name])
    );

    const rows: any[][] = [
      [
        "vendorName",
        "vendorId",
        "evidenceId",
        "title",
        "kind",
        "uploadedAt",
        "fileUrl",
        "description",
      ],
      ...records.map((e: any) => [
        vendorNameById.get(e.vendorId) ?? "",
        e.vendorId ?? "",
        e.id ?? "",
        e.title ?? "",
        e.kind ?? "",
        e.uploadedAt ? new Date(e.uploadedAt).toISOString() : "",
        e.fileUrl ?? "",
        e.description ?? "",
      ]),
    ];

    const csv = toCsv(rows);
    const suffix =
      actor.mode === "vendor"
        ? `-vendor-${actor.vendorId}`
        : vendorIdParam
        ? `-vendor-${vendorIdParam}`
        : "";

    return new NextResponse(csv, {
      status: 200,
      headers: {
        "content-type": "text/csv; charset=utf-8",
        "content-disposition": `attachment; filename="truvern-evidence${suffix}.csv"`,
      },
    });
  } catch (error) {
    console.error("Evidence export API error", error);
    return NextResponse.json({ ok: false, error: "Internal error" }, { status: 500 });
  }
}
