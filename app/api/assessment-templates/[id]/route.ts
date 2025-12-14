// app/api/assessment-templates/[id]/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

type RouteParams = {
  params: { id: string };
};

export async function GET(_req: Request, { params }: RouteParams) {
  const id = Number(params.id);
  if (!id || Number.isNaN(id)) {
    return NextResponse.json({ error: "Invalid id" }, { status: 400 });
  }

  const template = await prisma.assessmentTemplate.findUnique({
    where: { id },
    include: {
      sections: {
        orderBy: { order: "asc" },
        include: {
          questions: {
            orderBy: { orderIndex: "asc" },
          },
        },
      },
    },
  });

  if (!template) {
    return NextResponse.json({ error: "Not found" }, { status: 404 });
  }

  return NextResponse.json({
    id: template.id,
    name: template.name,
    description: template.description,
    standard: template.standard,
    category: template.category,
    version: template.version,
    code: template.code,
    isActive: template.isActive,
    sections: template.sections.map((s) => ({
      id: s.id,
      title: s.title,
      description: s.description,
      order: s.order,
      weight: s.weight,
      questions: s.questions.map((q) => ({
        id: q.id,
        text: q.text,
        helpText: q.helpText,
        type: q.type,
        richType: q.richType,
        required: q.required,
        weight: q.weight,
        key: q.key,
        options: q.options,
        orderIndex: q.orderIndex,
      })),
    })),
  });
}

export async function PATCH(req: Request, { params }: RouteParams) {
  const id = Number(params.id);
  if (!id || Number.isNaN(id)) {
    return NextResponse.json({ error: "Invalid id" }, { status: 400 });
  }

  const body = await req.json();

  try {
    const updated = await prisma.assessmentTemplate.update({
      where: { id },
      data: {
        name: body.name ?? undefined,
        description: body.description ?? undefined,
        standard: body.standard ?? undefined,
        category: body.category ?? undefined,
        version: body.version ?? undefined,
        isActive:
          typeof body.isActive === "boolean" ? body.isActive : undefined,
      },
    });

    return NextResponse.json({
      id: updated.id,
      name: updated.name,
      description: updated.description,
      standard: updated.standard,
      category: updated.category,
      version: updated.version,
      code: updated.code,
      isActive: updated.isActive,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    });
  } catch (err) {
    console.error("Error updating assessment template", err);
    return NextResponse.json(
      { error: "Failed to update template" },
      { status: 500 }
    );
  }
}

// Optional: soft-delete by marking inactive
export async function DELETE(_req: Request, { params }: RouteParams) {
  const id = Number(params.id);
  if (!id || Number.isNaN(id)) {
    return NextResponse.json({ error: "Invalid id" }, { status: 400 });
  }

  try {
    const updated = await prisma.assessmentTemplate.update({
      where: { id },
      data: {
        isActive: false,
      },
    });

    return NextResponse.json({
      id: updated.id,
      isActive: updated.isActive,
    });
  } catch (err) {
    console.error("Error soft-deleting assessment template", err);
    return NextResponse.json(
      { error: "Failed to deactivate template" },
      { status: 500 }
    );
  }
}
