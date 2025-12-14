// app/api/vendors/[id]/assessments/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

type RouteParams = {
  params: { id: string };
};

export async function POST(req: Request, { params }: RouteParams) {
  const vendorId = Number(params.id);
  if (!vendorId || Number.isNaN(vendorId)) {
    return NextResponse.json({ error: "Invalid vendor id" }, { status: 400 });
  }

  let body: {
    templateId: number;
    title?: string;
    dueAt?: string | null;
  };

  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { error: "Invalid JSON body" },
      { status: 400 }
    );
  }

  const templateId = Number(body.templateId);
  if (!templateId || Number.isNaN(templateId)) {
    return NextResponse.json(
      { error: "templateId is required" },
      { status: 400 }
    );
  }

  try {
    const vendor = await prisma.vendor.findUnique({
      where: { id: vendorId },
      include: {
        organization: true,
      },
    });

    if (!vendor || !vendor.organization) {
      return NextResponse.json(
        { error: "Vendor or organization not found" },
        { status: 404 }
      );
    }

    const template = await prisma.assessmentTemplate.findUnique({
      where: { id: templateId },
    });

    if (!template) {
      return NextResponse.json(
        { error: "Template not found" },
        { status: 404 }
      );
    }

    const dueAtDate =
      body.dueAt && body.dueAt.trim().length > 0
        ? new Date(body.dueAt)
        : null;

    const assessment = await prisma.assessment.create({
      data: {
        organizationId: vendor.organizationId,
        vendorId: vendor.id,
        templateId: template.id,
        status: "DRAFT",
        title: body.title?.trim() || template.name,
        dueAt: dueAtDate,
      },
    });

    const redirectUrl = `/assessments/${assessment.id}/run`;

    return NextResponse.json(
      {
        id: assessment.id,
        redirectUrl,
      },
      { status: 201 }
    );
  } catch (err) {
    console.error("Error creating vendor assessment", err);
    return NextResponse.json(
      { error: "Failed to create assessment" },
      { status: 500 }
    );
  }
}
