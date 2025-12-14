import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function getSectionIdFromUrl(req: NextRequest): number | null {
  try {
    const url = new URL(req.url);
    const segments = url.pathname.split("/").filter(Boolean);
    // .../templates/:id/sections/:sectionId
    const last = segments[segments.length - 1];
    const id = Number.parseInt(last, 10);
    if (Number.isNaN(id)) return null;
    return id;
  } catch {
    return null;
  }
}

export async function PATCH(req: NextRequest) {
  try {
    const sectionId = getSectionIdFromUrl(req);
    if (sectionId === null) {
      return NextResponse.json(
        { error: "Invalid section id" },
        { status: 400 }
      );
    }

    const body = await req.json();
    const data: any = {};

    if (typeof body.title === "string")
      data.title = body.title.trim();
    if (typeof body.description === "string")
      data.description = body.description.trim() || null;
    if (typeof body.weight === "number") data.weight = body.weight;
    if (typeof body.order === "number") data.order = body.order;

    const section = await prisma.assessmentSection.update({
      where: { id: sectionId },
      data,
    });

    return NextResponse.json(section);
  } catch (error) {
    console.error("Error updating section:", error);
    return NextResponse.json(
      { error: "Failed to update section" },
      { status: 500 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const sectionId = getSectionIdFromUrl(req);
    if (sectionId === null) {
      return NextResponse.json(
        { error: "Invalid section id" },
        { status: 400 }
      );
    }

    // Detach questions from this section
    await prisma.assessmentQuestion.updateMany({
      where: { sectionId },
      data: { sectionId: null },
    });

    await prisma.assessmentSection.delete({
      where: { id: sectionId },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error deleting section:", error);
    return NextResponse.json(
      { error: "Failed to delete section" },
      { status: 500 }
    );
  }
}
