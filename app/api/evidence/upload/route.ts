// app/api/evidence/upload/route.ts
import { NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export async function POST(req: Request) {
  try {
    const body = await req.json().catch(() => null);

    if (!body) {
      return NextResponse.json(
        { error: "Invalid JSON body" },
        { status: 400 }
      );
    }

    const {
      vendorId,
      title,
      description,
      fileUrl,
      uploadedBy,
    }: {
      vendorId?: number | string;
      title?: string;
      description?: string;
      fileUrl?: string;
      uploadedBy?: string;
    } = body;

    // Basic validation
    const idNum =
      typeof vendorId === "string"
        ? parseInt(vendorId, 10)
        : typeof vendorId === "number"
        ? vendorId
        : NaN;

    if (!Number.isInteger(idNum)) {
      return NextResponse.json(
        { error: "Missing or invalid vendorId" },
        { status: 400 }
      );
    }

    if (!title || !title.trim()) {
      return NextResponse.json(
        { error: "Title is required" },
        { status: 400 }
      );
    }

    // Optional: simple URL sanity check
    const normalizedFileUrl =
      typeof fileUrl === "string" && fileUrl.trim().length > 0
        ? fileUrl.trim()
        : null;

    const evidence = await prisma.evidence.create({
      data: {
        vendorId: idNum,
        title: title.trim(),
        description: description?.trim() || null,
        fileUrl: normalizedFileUrl,
        fileName: normalizedFileUrl || null,
        contentType: null,
        size: null,
        uploadedBy: uploadedBy?.trim() || "Console user",
        // createdAt is handled by @default(now()) in Prisma
      },
    });

    return NextResponse.json({ success: true, evidence }, { status: 201 });
  } catch (err) {
    console.error("[/api/evidence/upload] ERROR:", err);
    return NextResponse.json(
      {
        error: "Failed to create evidence entry",
      },
      { status: 500 }
    );
  }
}
