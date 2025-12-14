// app/api/vendors/create/route.ts
import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";
import { Prisma } from "@prisma/client";

function slugifyName(name: string): string {
  const base = name
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

  return base || `vendor-${Date.now()}`;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const nameRaw = body?.name;
    const riskScoreRaw = body?.riskScore;

    if (!nameRaw || typeof nameRaw !== "string") {
      return NextResponse.json(
        { error: "Vendor name is required." },
        { status: 400 }
      );
    }

    const name = nameRaw.trim();
    if (!name) {
      return NextResponse.json(
        { error: "Vendor name cannot be empty." },
        { status: 400 }
      );
    }

    // Optional risk score 0–100
    let riskScore: number | null = null;
    if (
      riskScoreRaw !== null &&
      riskScoreRaw !== undefined &&
      riskScoreRaw !== ""
    ) {
      const n = Number(riskScoreRaw);
      if (Number.isNaN(n) || n < 0 || n > 100) {
        return NextResponse.json(
          { error: "Risk score must be a number between 0 and 100." },
          { status: 400 }
        );
      }
      riskScore = n;
    }

    // Required slug, derived from name
    const slug = slugifyName(name);

    const baseData: any = {
      name,
      slug,
      ...(riskScore !== null ? { riskScore } : {}),
    };

    let vendor;

    // First try: assume Vendor has a required organization relation
    try {
      vendor = await prisma.vendor.create({
        data: {
          ...baseData,
          organization: {
            connect: { id: 1 },
          },
        },
      });
    } catch (err: any) {
      const msg = String(err?.message ?? "");

      // If organization is NOT part of the model, retry without it
      if (
        msg.includes("Unknown arg `organization`") ||
        msg.includes("Unknown argument `organization`")
      ) {
        vendor = await prisma.vendor.create({
          data: baseData,
        });
      } else if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === "P2002"
      ) {
        // Unique constraint on name or slug
        return NextResponse.json(
          {
            error:
              "A vendor with that name (or slug) already exists. Try a slightly different name.",
          },
          { status: 409 }
        );
      } else {
        throw err;
      }
    }

    return NextResponse.json({ vendor }, { status: 201 });
  } catch (err: any) {
    console.error("Create vendor error:", err);
    return NextResponse.json(
      { error: err?.message ?? "Failed to create vendor." },
      { status: 500 }
    );
  }
}
