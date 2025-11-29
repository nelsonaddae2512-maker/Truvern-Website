import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

// Health check GET – just return 200 OK
export async function GET() {
  return NextResponse.json({ status: "ok" }, { status: 200 });
}

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();

    const vendorIdRaw = formData.get("vendorId");
    const file = formData.get("file") as File | null;
    const notesRaw = formData.get("notes");

    if (!vendorIdRaw || !file) {
      return NextResponse.json(
        { error: "Missing vendorId or file" },
        { status: 400 }
      );
    }

    const vendorId = Number(vendorIdRaw);
    if (!Number.isInteger(vendorId)) {
      return NextResponse.json(
        { error: "Invalid vendorId" },
        { status: 400 }
      );
    }

    const notes = notesRaw ? String(notesRaw) : null;

    // Convert File to Buffer for Prisma Bytes
    const arrayBuffer = await file.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    const evidence = await prisma.evidence.create({
      data: {
        vendorId,
        filename: file.name || "evidence",
        mimeType: file.type || "application/octet-stream",
        size: buffer.length,
        notes,
        data: buffer,
      },
    });

    console.log("Created evidence", evidence.id, "for vendor", vendorId);

    // Redirect back to vendor detail page
    const redirectUrl = new URL(`/vendors/${vendorId}`, req.url);
    return NextResponse.redirect(redirectUrl.toString(), { status: 303 });
  } catch (error) {
    console.error("Error in /vendor/upload-file POST:", error);
    return NextResponse.json(
      { error: "Failed to upload evidence" },
      { status: 500 }
    );
  }
}
