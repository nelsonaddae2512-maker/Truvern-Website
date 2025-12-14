// app/api/evidence/create/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

// Valid enum EvidenceKind values: POLICY | REPORT | SCREENSHOT | CERTIFICATE | OTHER
const ALLOWED_KINDS = ["POLICY", "REPORT", "SCREENSHOT", "CERTIFICATE", "OTHER"] as const;
const DEFAULT_EVIDENCE_KIND = "OTHER";

export async function POST(req: NextRequest) {
  try {
    let body: any;

    try {
      body = await req.json();
    } catch {
      return NextResponse.json(
        { error: "Invalid JSON body." },
        { status: 400 }
      );
    }

    const { vendorId, title, fileName, kind } = body ?? {};

    if (vendorId == null || Number.isNaN(Number(vendorId))) {
      return NextResponse.json(
        { error: "vendorId is required." },
        { status: 400 }
      );
    }

    const numericVendorId = Number(vendorId);

    // Load vendor and its organizationId (if present)
    const vendor = await prisma.vendor.findUnique({
      where: { id: numericVendorId },
      select: {
        id: true,
        organizationId: true,
      },
    });

    if (!vendor) {
      return NextResponse.json(
        { error: "Vendor not found." },
        { status: 404 }
      );
    }

    // Resolve organizationId to satisfy Evidence.organization required relation
    let organizationId = vendor.organizationId ?? null;

    if (!organizationId) {
      const org = await prisma.organization.findFirst({
        select: { id: true },
      });

      if (!org) {
        return NextResponse.json(
          {
            error:
              "No organization available to attach evidence to. Create an Organization first.",
          },
          { status: 500 }
        );
      }

      organizationId = org.id;
    }

    const safeTitle =
      (typeof title === "string" && title.trim()) ||
      (typeof fileName === "string" && fileName.trim()) ||
      "Evidence";

    const mockFileUrl =
      typeof fileName === "string" && fileName.trim()
        ? `mock://local/${encodeURIComponent(fileName.trim())}`
        : null;

    // Normalize and validate kind coming from the client
    const rawKind =
      typeof kind === "string" ? kind.trim().toUpperCase() : "";
    const effectiveKind = ALLOWED_KINDS.includes(rawKind as any)
      ? rawKind
      : DEFAULT_EVIDENCE_KIND;

    const evidence = await prisma.evidence.create({
      data: {
        vendorId: numericVendorId,
        organizationId,
        title: safeTitle,
        description: null,
        fileUrl: mockFileUrl,
        kind: effectiveKind,
        // uploadedAt will use @default(now()) if set in schema
      },
    });

    return NextResponse.json({ evidence }, { status: 201 });
  } catch (err: any) {
    console.error("Error creating evidence:", err);
    return NextResponse.json(
      {
        error: err?.message ?? "Unexpected error while creating evidence.",
      },
      { status: 500 }
    );
  }
}
