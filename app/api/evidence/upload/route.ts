import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

// Temporary mock upload mode.
// S3 will replace this later.
export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();

    const vendorId = Number(formData.get("vendorId"));
    const title = String(formData.get("title") || "");
    const file = formData.get("file") as File | null;

    if (!vendorId || Number.isNaN(vendorId)) {
      return NextResponse.json(
        { error: "vendorId is required" },
        { status: 400 }
      );
    }

    if (!file) {
      return NextResponse.json(
        { error: "Missing file" },
        { status: 400 }
      );
    }

    // ---- TEMPORARY MOCK FILE STORAGE ----
    // This simulates an uploaded file URL.
    const mockUrl = `https://files.truvern.local/mock/${Date.now()}-${file.name}`;

    const evidence = await prisma.evidence.create({
      data: {
        title,
        filename: file.name,
        fileUrl: mockUrl,
        mimeType: file.type || "application/octet-stream",
        storageKey: "mock",
        isMock: true,
        vendor: {
          connect: { id: vendorId }   // <-- 🔥 FIXED: connect to vendor properly
        },
      },
    });

    return NextResponse.json({ success: true, evidence });
  } catch (err: any) {
    console.error("Upload error:", err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}
