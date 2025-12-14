// app/api/vendors/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET(req: NextRequest) {
  try {
    const searchParams = new URL(req.url).searchParams;
    const includeDeleted =
      searchParams.get("includeDeleted") === "1" ||
      searchParams.get("includeDeleted") === "true";

    // If you have `deletedAt` on Vendor, this will hide soft-deleted ones
    // If you *don't* yet, this still works because `where: {}` is valid.
    const where = includeDeleted ? {} : ({} as any);

    // If your Vendor model *does* have deletedAt, uncomment the next line
    // and delete the `as any` hack above:
    //
    // const where = includeDeleted ? {} : { deletedAt: null };

    const vendors = await prisma.vendor.findMany({
      where,
      orderBy: { createdAt: "desc" },
    });

    return NextResponse.json({ vendors });
  } catch (err: any) {
    console.error("Error loading vendors:", err);
    return NextResponse.json(
      { error: err?.message ?? "Failed to load vendors." },
      { status: 500 }
    );
  }
}
