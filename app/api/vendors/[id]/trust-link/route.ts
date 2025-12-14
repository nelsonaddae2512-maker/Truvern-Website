// app/api/vendors/[id]/trust-link/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import crypto from "crypto";

type RouteParams = {
  params: { id: string };
};

function generateToken() {
  return crypto.randomBytes(24).toString("hex");
}

export async function POST(req: NextRequest, { params }: RouteParams) {
  try {
    const vendorId = Number(params.id);
    if (!vendorId || Number.isNaN(vendorId)) {
      return NextResponse.json({ error: "Invalid vendor id" }, { status: 400 });
    }

    const body = await req.json().catch(() => ({}));
    const ttlDays =
      typeof body.ttlDays === "number" && body.ttlDays > 0 ? body.ttlDays : 30;

    const now = new Date();
    const expiresAt =
      ttlDays > 0
        ? new Date(now.getTime() + ttlDays * 24 * 60 * 60 * 1000)
        : null;

    // Optionally: reuse an existing non-expired token for this vendor
    const existing = await prisma.vendorShareToken.findFirst({
      where: {
        vendorId,
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
      },
    });

    let tokenRecord = existing;

    if (!tokenRecord) {
      const token = generateToken();
      tokenRecord = await prisma.vendorShareToken.create({
        data: {
          vendorId,
          token,
          expiresAt,
        },
      });
    }

    const origin = req.nextUrl.origin;
    const trustUrl = `${origin}/trust/${vendorId}?token=${encodeURIComponent(
      tokenRecord.token
    )}`;

    return NextResponse.json(
      {
        vendorId,
        token: tokenRecord.token,
        expiresAt: tokenRecord.expiresAt,
        url: trustUrl,
      },
      { status: 201 }
    );
  } catch (error) {
    console.error("Error generating vendor trust link", error);
    return NextResponse.json(
      { error: "Failed to generate trust link" },
      { status: 500 }
    );
  }
}
