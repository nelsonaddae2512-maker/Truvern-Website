import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

// GET /api/assessment/runs/options
// Returns minimal vendor + template lists for the create-run form
export async function GET(_req: NextRequest) {
  try {
    const [vendors, templates] = await Promise.all([
      prisma.vendor.findMany({
        orderBy: { name: "asc" },
        select: { id: true, name: true },
      }),
      prisma.assessmentTemplate.findMany({
        orderBy: { name: "asc" },
        select: { id: true, name: true },
      }),
    ]);

    return NextResponse.json({ vendors, templates });
  } catch (error) {
    console.error("Error loading assessment run options:", error);
    return NextResponse.json(
      { error: "Failed to load options" },
      { status: 500 }
    );
  }
}
