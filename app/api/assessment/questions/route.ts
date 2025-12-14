import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url);
    const templateIdParam = url.searchParams.get("templateId");
    const unattached = url.searchParams.get("unattached");

    const where: any = {};

    if (templateIdParam) {
      const tId = Number.parseInt(templateIdParam, 10);
      if (!Number.isNaN(tId)) {
        where.templateId = tId;
      }
    } else if (unattached === "true") {
      where.templateId = null;
    }

    const questions = await prisma.assessmentQuestion.findMany({
      where,
      orderBy: { createdAt: "desc" },
    });

    const payload = questions.map((q) => ({
      ...q,
      createdAt: q.createdAt.toISOString(),
      updatedAt: q.updatedAt.toISOString(),
    }));

    return NextResponse.json(payload);
  } catch (error) {
    console.error("Error loading assessment questions:", error);
    return NextResponse.json(
      { error: "Failed to load questions" },
      { status: 500 }
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const text =
      typeof body.text === "string" ? body.text.trim() : "";
    const description =
      typeof body.description === "string" && body.description.trim()
        ? body.description.trim()
        : null;
    const type =
      typeof body.type === "string" && body.type.trim()
        ? (body.type.trim() as any)
        : "YES_NO";
    const category =
      typeof body.category === "string" && body.category.trim()
        ? body.category.trim()
        : null;

    // Optional: template + section for template builder
    let templateId: number | null = null;
    if (body.templateId !== undefined && body.templateId !== null) {
      const parsed = Number(body.templateId);
      if (!Number.isNaN(parsed)) {
        templateId = parsed;
      }
    }

    let sectionId: number | null = null;
    if (body.sectionId !== undefined && body.sectionId !== null) {
      const parsed = Number(body.sectionId);
      if (!Number.isNaN(parsed)) {
        sectionId = parsed;
      }
    }

    if (!text) {
      return NextResponse.json(
        { error: "Question text is required" },
        { status: 400 }
      );
    }

    // orderIndex per template (or global if no templateId)
    const whereForOrder: any = {};
    if (templateId !== null) {
      whereForOrder.templateId = templateId;
    }

    const aggregate = await prisma.assessmentQuestion.aggregate({
      where: whereForOrder,
      _max: { orderIndex: true },
    });
    const nextOrderIndex = (aggregate._max.orderIndex ?? 0) + 1;

    const created = await prisma.assessmentQuestion.create({
      data: {
        text,
        helpText: description,
        description,
        category,
        type,
        templateId,
        sectionId,
        orderIndex: nextOrderIndex,
      },
    });

    const payload = {
      ...created,
      createdAt: created.createdAt.toISOString(),
      updatedAt: created.updatedAt.toISOString(),
    };

    return NextResponse.json(payload, { status: 201 });
  } catch (error: any) {
    console.error("Error creating assessment question:", error);

    return NextResponse.json(
      { error: "Failed to create question" },
      { status: 500 }
    );
  }
}
