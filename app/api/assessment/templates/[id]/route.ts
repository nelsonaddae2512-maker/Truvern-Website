import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

// Grab template id from URL: /api/assessment/templates/123
function getTemplateIdFromUrl(req: NextRequest): number | null {
  try {
    const url = new URL(req.url);
    const segments = url.pathname.split("/").filter(Boolean);
    const last = segments[segments.length - 1];
    const id = Number.parseInt(last, 10);
    if (Number.isNaN(id)) return null;
    return id;
  } catch {
    return null;
  }
}

export async function GET(req: NextRequest) {
  try {
    const id = getTemplateIdFromUrl(req);
    if (id === null) {
      return NextResponse.json(
        { error: "Invalid template id" },
        { status: 400 }
      );
    }

    const template = await prisma.assessmentTemplate.findUnique({
      where: { id },
      include: {
        sections: {
          orderBy: { order: "asc" },
        },
        questions: {
          orderBy: { orderIndex: "asc" },
        },
      },
    });

    if (!template) {
      return NextResponse.json(
        { error: "Template not found" },
        { status: 404 }
      );
    }

    const payload = {
      id: template.id,
      name: template.name,
      description: template.description,
      standard: template.standard,
      code: template.code,
      category: template.category,
      version: template.version,
      isActive: template.isActive,
      createdAt: template.createdAt.toISOString(),
      updatedAt: template.updatedAt.toISOString(),
      sections: template.sections.map((s) => ({
        id: s.id,
        title: s.title,
        description: s.description,
        order: s.order,
        weight: s.weight,
      })),
      questions: template.questions.map((q) => ({
        id: q.id,
        text: q.text,
        helpText: q.helpText,
        description: q.description,
        category: q.category,
        type: q.type,
        richType: q.richType,
        sectionId: q.sectionId,
        orderIndex: q.orderIndex,
        required: q.required,
        weight: q.weight,
        createdAt: q.createdAt.toISOString(),
        updatedAt: q.updatedAt.toISOString(),
      })),
    };

    return NextResponse.json(payload);
  } catch (error) {
    console.error("Error loading template:", error);
    return NextResponse.json(
      { error: "Failed to load template" },
      { status: 500 }
    );
  }
}

export async function PATCH(req: NextRequest) {
  try {
    const id = getTemplateIdFromUrl(req);
    if (id === null) {
      return NextResponse.json(
        { error: "Invalid template id" },
        { status: 400 }
      );
    }

    const body = await req.json();

    const data: any = {};
    if (typeof body.name === "string") data.name = body.name.trim();
    if (typeof body.description === "string")
      data.description = body.description.trim() || null;
    if (typeof body.standard === "string")
      data.standard = body.standard.trim() || null;
    if (typeof body.code === "string")
      data.code = body.code.trim() || null;
    if (typeof body.category === "string")
      data.category = body.category.trim() || null;
    if (typeof body.version === "string")
      data.version = body.version.trim() || null;
    if (typeof body.isActive === "boolean")
      data.isActive = body.isActive;

    const updated = await prisma.assessmentTemplate.update({
      where: { id },
      data,
    });

    const payload = {
      ...updated,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    };

    return NextResponse.json(payload);
  } catch (error) {
    console.error("Error updating template:", error);
    return NextResponse.json(
      { error: "Failed to update template" },
      { status: 500 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const id = getTemplateIdFromUrl(req);
    if (id === null) {
      return NextResponse.json(
        { error: "Invalid template id" },
        { status: 400 }
      );
    }

    // Optional: detach questions instead of failing on FK
    await prisma.assessmentQuestion.updateMany({
      where: { templateId: id },
      data: { templateId: null, sectionId: null },
    });

    await prisma.assessmentSection.deleteMany({
      where: { templateId: id },
    });

    await prisma.assessmentTemplate.delete({
      where: { id },
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error deleting template:", error);
    return NextResponse.json(
      { error: "Failed to delete template" },
      { status: 500 }
    );
  }
}
