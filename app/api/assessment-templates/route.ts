// app/api/assessment-templates/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

export async function GET() {
  const templates = await prisma.assessmentTemplate.findMany({
    orderBy: { createdAt: "desc" },
    include: {
      _count: {
        select: {
          assessments: true,
        },
      },
    },
  });

  const payload = templates.map((t) => ({
    id: t.id,
    name: t.name,
    description: t.description,
    standard: t.standard,
    code: t.code,
    category: t.category,
    version: t.version,
    isActive: t.isActive,
    createdAt: t.createdAt.toISOString(),
    updatedAt: t.updatedAt.toISOString(),
    assessmentCount: t._count.assessments,
  }));

  return NextResponse.json(payload);
}

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const name: string = body.name || "New assessment template";
    const description: string | null = body.description ?? null;
    const standard: string | null = body.standard ?? null;
    const category: string | null = body.category ?? null;
    const version: string | null = body.version ?? null;

    const baseCode =
      name
        .toUpperCase()
        .replace(/[^A-Z0-9]+/g, "_")
        .replace(/^_+|_+$/g, "") || "TEMPLATE";

    let code = baseCode;
    let suffix = 1;
    // Ensure uniqueness of code (optional, defensive)
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const existing = await prisma.assessmentTemplate.findUnique({
        where: { code },
      });
      if (!existing) break;
      code = `${baseCode}_${suffix++}`;
    }

    const template = await prisma.assessmentTemplate.create({
      data: {
        name,
        description,
        standard,
        category,
        version,
        code,
        isActive: true,
        organizationId: null, // global template for now
      },
    });

    return NextResponse.json(
      {
        id: template.id,
        name: template.name,
        description: template.description,
        standard: template.standard,
        category: template.category,
        version: template.version,
        code: template.code,
        isActive: template.isActive,
        createdAt: template.createdAt.toISOString(),
        updatedAt: template.updatedAt.toISOString(),
      },
      { status: 201 }
    );
  } catch (err) {
    console.error("Error creating assessment template", err);
    return NextResponse.json(
      { error: "Failed to create template" },
      { status: 500 }
    );
  }
}
