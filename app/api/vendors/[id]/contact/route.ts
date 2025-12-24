// app/api/vendors/[id]/contact/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { requireDbOrganization } from "@/lib/org-db";

function safeStr(v: unknown) {
  return typeof v === "string" ? v.trim() : v == null ? "" : String(v).trim();
}

function isValidEmail(email: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function normalizePhone(v: string) {
  // Keep digits and leading +, strip everything else.
  const s = v.trim();
  if (!s) return null;
  const cleaned = s.replace(/[^\d+]/g, "");
  return cleaned || null;
}

export async function POST(req: NextRequest, { params }: { params: Promise<{ id: string }> }) {
  try {
    const org = await requireDbOrganization();

    const { id } = await params;
    const vendorId = Number(id);
    if (!Number.isFinite(vendorId) || vendorId <= 0) {
      return NextResponse.json({ ok: false, error: "Invalid vendorId" }, { status: 400 });
    }

    // Ensure vendor belongs to org
    const vendor = await prisma.vendor.findFirst({
      where: { id: vendorId, organizationId: org.id },
      select: { id: true, contactName: true, contactEmail: true },
    });

    if (!vendor) {
      return NextResponse.json({ ok: false, error: "Vendor not found" }, { status: 404 });
    }

    const body = await req.json().catch(() => ({} as any));

    // Backward-compatible payload:
    // { contactName, contactEmail }  (existing UI)
    // Extended payload:
    // { contactName, contactEmail, phone, makePrimary }
    const contactName = safeStr(body?.contactName) || null;
    const emailRaw = safeStr(body?.contactEmail);
    const contactEmail = emailRaw ? emailRaw.toLowerCase() : null;

    const phoneRaw = safeStr(body?.phone);
    const phone = phoneRaw ? normalizePhone(phoneRaw) : null;

    const makePrimary = !!body?.makePrimary;

    if (!contactEmail || !isValidEmail(contactEmail)) {
      return NextResponse.json({ ok: false, error: "Invalid email" }, { status: 400 });
    }

    // If VendorContact model exists, use multi-contact flow.
    // Otherwise (before migration), fall back to legacy fields.
    const hasVendorContactModel = !!(prisma as any).vendorContact;

    if (!hasVendorContactModel) {
      await prisma.vendor.updateMany({
        where: { id: vendorId, organizationId: org.id },
        data: { contactName, contactEmail } as any,
      });

      return NextResponse.json({
        ok: true,
        vendorId,
        mode: "legacy",
        contactName,
        contactEmail,
      });
    }

    // Enforce max 3 contacts per vendor
    const existingCount = await (prisma as any).vendorContact.count({
      where: { vendorId },
    });

    // If this email already exists, update it (name/phone/primary) instead of counting against limit
    const existing = await (prisma as any).vendorContact.findFirst({
      where: { vendorId, email: contactEmail },
      select: { id: true, isPrimary: true },
    });

    if (!existing && existingCount >= 3) {
      return NextResponse.json({ ok: false, error: "Max 3 contact emails allowed" }, { status: 400 });
    }

    let contactId: number;

    if (existing) {
      const updated = await (prisma as any).vendorContact.update({
        where: { id: existing.id },
        data: {
          name: contactName,
          phone,
        },
        select: { id: true },
      });
      contactId = updated.id;
    } else {
      const created = await (prisma as any).vendorContact.create({
        data: {
          vendorId,
          email: contactEmail,
          name: contactName,
          phone,
          // default non-primary; may be promoted below
          isPrimary: false,
          // role can be set later if you want (PRIMARY/SECURITY/etc)
        },
        select: { id: true },
      });
      contactId = created.id;
    }

    // Decide primary contact:
    // - If caller requests makePrimary, set it.
    // - Else if no primary exists, set this as primary.
    const hasPrimary = await (prisma as any).vendorContact.findFirst({
      where: { vendorId, isPrimary: true },
      select: { id: true },
    });

    if (makePrimary || !hasPrimary) {
      await (prisma as any).vendorContact.updateMany({
        where: { vendorId },
        data: { isPrimary: false },
      });
      await (prisma as any).vendorContact.update({
        where: { id: contactId },
        data: { isPrimary: true },
      });
    }

    // Keep legacy fields in sync with the PRIMARY contact (helps older UI & queries)
    const primary = await (prisma as any).vendorContact.findFirst({
      where: { vendorId, isPrimary: true },
      select: { name: true, email: true },
    });

    if (primary?.email) {
      await prisma.vendor.updateMany({
        where: { id: vendorId, organizationId: org.id },
        data: {
          contactName: primary.name || null,
          contactEmail: primary.email || null,
        } as any,
      });
    }

    return NextResponse.json({
      ok: true,
      vendorId,
      mode: "contacts",
      contactId,
      contactName,
      contactEmail,
      phone,
      primaryEmail: primary?.email || null,
    });
  } catch (e: any) {
    return NextResponse.json(
      { ok: false, error: e?.message || "Server error" },
      { status: 500 }
    );
  }
}
