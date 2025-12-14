// app/api/trust-link/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

const BASE_URL =
  process.env.NEXT_PUBLIC_APP_URL?.replace(/\/$/, "") || "https://truvern.com";

export async function GET(req: NextRequest) {
  try {
    const vendorIdParam = req.nextUrl.searchParams.get("vendorId");
    const vendorId = Number(vendorIdParam);

    if (!vendorIdParam || Number.isNaN(vendorId)) {
      return NextResponse.json(
        { error: "Invalid vendor id" },
        { status: 400 }
      );
    }

    const vendor = await prisma.vendor.findUnique({
      where: { id: vendorId },
      select: { id: true },
    });

    if (!vendor) {
      return NextResponse.json(
        { error: "Vendor not found" },
        { status: 404 }
      );
    }

    // ✅ New public trust URL
    const url = `${BASE_URL}/trust/${vendor.id}`;

    return NextResponse.json({ url });
  } catch (err) {
    console.error("Error generating trust link:", err);
    return NextResponse.json(
      { error: "Internal error while generating trust link" },
      { status: 500 }
    );
  }
}
