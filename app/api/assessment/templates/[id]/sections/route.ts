import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function getTemplateIdFromUrl(req: NextRequest): number | null {
  try {
    const url = new URL(req.url);
    const segments = url.pathname.split("/").filter(Boolean);
    // .../templates/:id/sections
    const templateIndex = segments.indexOf("templates") + 1;
    const raw = segments[templateIndex];
    const id = Number.parseInt(raw, 10);
    if (Number.isNaN(id)) return null;
    return id;
  } catch {
    return null;
  }
}

export async function POST(req: NextRequest) {
  try {
    const templateId = getTemplateIdFromUrl(req);
    if (templateId === null) {
      return NextResponse.json(
        { error: "Invalid template id" },
        { status: 400 }
      );
    }

    const body = await req.json();
    const title =
      typeof body.title === "string" ? body.title.trim() : "";
    const description =
      typeof body.description === "string" && body.description.trim()
        ? body.description.trim()
        : null;
    const weight =
      typeof body.weight === "number" ? body.weight : null;

    if (!title) {
      return NextResponse.json(
        { error: "Section title is required" },
        { status: 400 }
      );
    }

    const agg = await prisma.assessmentSection.aggregate({
      where: { templateId },
      _max: { order: true },
    });

    const nextOrder = (agg._max.order ?? 0) + 1;

    const section = await prisma.assessmentSection.create({
      data: {
        templateId,
        title,
        description,
        weight,
        order: nextOrder,
      },
    });

    const payload = {
      ...section,
      // createdAt/updatedAt don't exist on this model currently
    };

    return NextResponse.json(payload, { status: 201 });
  } catch (error) {
    console.error("Error creating section:", error);
    return NextResponse.json(
      { error: "Failed to create section" },
      { status: 500 }
    );
  }
}
