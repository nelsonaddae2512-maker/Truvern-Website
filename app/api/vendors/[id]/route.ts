// app/api/vendors/[id]/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

async function assertVendorInOrg(organizationId: number, vendorId: number) {
  const v = await prisma.vendor.findFirst({
    where: { id: vendorId, organizationId },
    select: { id: true, deletedAt: true, name: true },
  });
  return v;
}

export async function PATCH(req: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const org = await requireDbOrganization();
    const organizationId = org.id;

    const { id } = await params;
    const vendorId = Number(id);
    if (!Number.isFinite(vendorId)) {
      return NextResponse.json({ error: "Invalid vendor id." }, { status: 400 });
    }

    const existing = await assertVendorInOrg(organizationId, vendorId);
    if (!existing) {
      return NextResponse.json({ error: "Vendor not found." }, { status: 404 });
    }

    const body = await req.json().catch(() => ({}));

    // ✅ Archive/restore (soft delete)
    if (body?.archive === true) {
      const updated = await prisma.vendor.update({
        where: { id: vendorId },
        data: { deletedAt: new Date(), status: "ARCHIVED" } as any,
        select: { id: true },
      });

      await prisma.activityEvent
        .create({
          data: {
            organizationId,
            vendorId: updated.id,
            type: "VENDOR_ARCHIVED",
            title: "Vendor archived",
            description: `Archived vendor: ${existing.name ?? `#${vendorId}`}`,
          },
        })
        .catch(() => null);

      return NextResponse.json({ ok: true, id: updated.id, archived: true });
    }

    if (body?.restore === true) {
      const updated = await prisma.vendor.update({
        where: { id: vendorId },
        data: { deletedAt: null, status: "ACTIVE" } as any,
        select: { id: true },
      });

      await prisma.activityEvent
        .create({
          data: {
            organizationId,
            vendorId: updated.id,
            type: "VENDOR_RESTORED",
            title: "Vendor restored",
            description: `Restored vendor: ${existing.name ?? `#${vendorId}`}`,
          },
        })
        .catch(() => null);

      return NextResponse.json({ ok: true, id: updated.id, restored: true });
    }

    // ✅ Normal field updates (unchanged behavior)
    const name = typeof body?.name === "string" ? body.name.trim() : undefined;
    const summary = typeof body?.summary === "string" ? (body.summary.trim() || null) : undefined;
    const category = typeof body?.category === "string" ? (body.category.trim() || null) : undefined;
    const tier = typeof body?.tier === "string" ? (body.tier.trim() || null) : undefined;
    const criticality =
      typeof body?.criticality === "string" ? (body.criticality.trim() || null) : undefined;
    const status = typeof body?.status === "string" ? (body.status.trim() || null) : undefined;

    if (name !== undefined && !name) {
      return NextResponse.json({ error: "Vendor name cannot be empty." }, { status: 400 });
    }

    const updated = await prisma.vendor.update({
      where: { id: vendorId },
      data: {
        ...(name !== undefined ? { name } : {}),
        ...(summary !== undefined ? { summary } : {}),
        ...(category !== undefined ? { category } : {}),
        ...(tier !== undefined ? { tier: tier as any } : {}),
        ...(criticality !== undefined ? { criticality: criticality as any } : {}),
        ...(status !== undefined ? { status } : {}),
      } as any,
      select: { id: true },
    });

    await prisma.activityEvent
      .create({
        data: {
          organizationId,
          vendorId: updated.id,
          type: "VENDOR_UPDATED",
          title: "Vendor updated",
          description: `Updated vendor fields for id=${updated.id}`,
          metadata: {
            fields: ["name", "summary", "category", "tier", "criticality", "status"].filter(
              (k) => (body as any)?.[k] !== undefined
            ),
          },
        },
      })
      .catch(() => null);

    return NextResponse.json({ ok: true, id: updated.id });
  } catch (err: any) {
    return NextResponse.json(
      { error: "Failed to update vendor.", detail: String(err?.message ?? err) },
      { status: 500 }
    );
  }
}

export async function DELETE(req: Request, { params }: { params: Promise<{ id: string }> }) {
  try {
    const org = await requireDbOrganization();
    const organizationId = org.id;

    const { id } = await params;
    const vendorId = Number(id);
    if (!Number.isFinite(vendorId)) {
      return NextResponse.json({ error: "Invalid vendor id." }, { status: 400 });
    }

    const existing = await assertVendorInOrg(organizationId, vendorId);
    if (!existing) {
      return NextResponse.json({ error: "Vendor not found." }, { status: 404 });
    }

    const updated = await prisma.vendor.update({
      where: { id: vendorId },
      data: { deletedAt: new Date(), status: "ARCHIVED" } as any,
      select: { id: true },
    });

    await prisma.activityEvent
      .create({
        data: {
          organizationId,
          vendorId: updated.id,
          type: "VENDOR_ARCHIVED",
          title: "Vendor archived",
          description: `Archived vendor: ${existing.name ?? `#${vendorId}`}`,
        },
      })
      .catch(() => null);

    return NextResponse.json({ ok: true, id: updated.id, archived: true });
  } catch (err: any) {
    return NextResponse.json(
      { error: "Failed to archive vendor.", detail: String(err?.message ?? err) },
      { status: 500 }
    );
  }
}
