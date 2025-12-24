// app/api/vendor/evidence-upload/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import path from "path";
import { promises as fs } from "fs";
import crypto from "crypto";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function safeExt(name: string) {
  const ext = path.extname(name || "").toLowerCase();
  if (!ext) return "";
  // keep simple/safe extensions; fallback to empty
  if (ext.length > 10) return "";
  return ext.replace(/[^a-z0-9.]/g, "");
}

export async function POST(req: NextRequest) {
  try {
    const form = await req.formData();

    const vendorId = Number(form.get("vendorId"));
    const evidenceRequestId = Number(form.get("evidenceRequestId"));
    const titleRaw = typeof form.get("note") === "string" ? String(form.get("note")).trim() : "";
    const title = titleRaw || "Evidence upload";
    const kindRaw = typeof form.get("kind") === "string" ? String(form.get("kind")).trim() : "";
    const kind = kindRaw || "OTHER";

    const file = form.get("file") as File | null;

    if (!Number.isFinite(vendorId)) {
      return NextResponse.json({ ok: false, error: "Missing vendorId" }, { status: 400 });
    }
    if (!Number.isFinite(evidenceRequestId)) {
      return NextResponse.json({ ok: false, error: "Missing evidenceRequestId" }, { status: 400 });
    }
    if (!file) {
      return NextResponse.json({ ok: false, error: "Missing file" }, { status: 400 });
    }

    // Validate request belongs to vendor + get org
    const reqRow = await prisma.evidenceRequest.findUnique({
      where: { id: evidenceRequestId },
      select: { id: true, vendorId: true, organizationId: true },
    });

    if (!reqRow) {
      return NextResponse.json({ ok: false, error: "Evidence request not found" }, { status: 404 });
    }
    if (reqRow.vendorId !== vendorId) {
      return NextResponse.json(
        { ok: false, error: "Unauthorized for this evidence request" },
        { status: 403 }
      );
    }
    if (!reqRow.organizationId) {
      return NextResponse.json(
        { ok: false, error: "Evidence request missing organization context" },
        { status: 500 }
      );
    }

    // Save file to /public/uploads
    const bytes = Buffer.from(await file.arrayBuffer());
    const ext = safeExt(file.name);
    const id = crypto.randomBytes(12).toString("hex");
    const fileBase = `evidence_${evidenceRequestId}_${id}${ext || ""}`;

    const uploadsDir = path.join(process.cwd(), "public", "uploads");
    await fs.mkdir(uploadsDir, { recursive: true });

    const absPath = path.join(uploadsDir, fileBase);
    await fs.writeFile(absPath, bytes);

    // Public URL
    const fileUrl = `/uploads/${fileBase}`;

    const evidence = await prisma.evidence.create({
      data: {
        title,
        description: title, // optional field per your schema output
        fileUrl, // ✅ THIS exists in your schema
        kind: kind as any,

        vendor: { connect: { id: vendorId } },
        organization: { connect: { id: reqRow.organizationId } },
        evidenceRequest: { connect: { id: evidenceRequestId } },
      } as any,
    });

    await prisma.evidenceRequest.update({
      where: { id: evidenceRequestId },
      data: {
        status: "SUBMITTED",
        submittedAt: new Date(),
        reviewedAt: null,
        reviewNote: null,
        evidenceId: (evidence as any).id,
      } as any,
    });

    return NextResponse.json({
      ok: true,
      evidenceId: (evidence as any).id,
      title: (evidence as any).title,
      fileUrl,
    });
  } catch (e: any) {
    console.error("vendor-evidence-upload error", e);
    return NextResponse.json({ ok: false, error: e?.message || "Upload failed" }, { status: 500 });
  }
}
