import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

// GET /api/assessment/runs
// Optional query params: ?vendorId=..&status=..
export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url);
    const vendorIdParam = url.searchParams.get("vendorId");
    const statusParam = url.searchParams.get("status");

    const where: any = {};

    if (vendorIdParam) {
      const vendorId = Number.parseInt(vendorIdParam, 10);
      if (!Number.isNaN(vendorId)) {
        where.vendorId = vendorId;
      }
    }

    if (statusParam) {
      // should match AssessmentStatus enum values
      where.status = statusParam;
    }

    const assessments = await prisma.assessment.findMany({
      where,
      orderBy: { updatedAt: "desc" },
      include: {
        vendor: {
          select: { id: true, name: true },
        },
        template: {
          select: { id: true, name: true },
        },
      },
    });

    const payload = assessments.map((a) => ({
      id: a.id,
      title: a.title,
      status: a.status,
      vendorId: a.vendorId,
      vendorName: a.vendor?.name ?? "Unknown vendor",
      templateId: a.templateId,
      templateName: a.template?.name ?? null,
      createdAt: a.createdAt.toISOString(),
      updatedAt: a.updatedAt.toISOString(),
      dueAt: a.dueAt ? a.dueAt.toISOString() : null,
      completedAt: a.completedAt ? a.completedAt.toISOString() : null,
    }));

    return NextResponse.json(payload);
  } catch (error) {
    console.error("Error loading assessment runs:", error);
    return NextResponse.json(
      { error: "Failed to load assessment runs" },
      { status: 500 }
    );
  }
}

// POST /api/assessment/runs
// Body: { vendorId, templateId?, title?, dueAt? }
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const vendorId =
      typeof body.vendorId === "number"
        ? body.vendorId
        : Number.parseInt(String(body.vendorId ?? ""), 10);
    const templateIdRaw =
      body.templateId === null || body.templateId === undefined
        ? null
        : Number.parseInt(String(body.templateId), 10);

    const title =
      typeof body.title === "string" ? body.title.trim() : "";
    const dueAt =
      typeof body.dueAt === "string" && body.dueAt.trim()
        ? new Date(body.dueAt)
        : null;

    if (!vendorId || Number.isNaN(vendorId)) {
      return NextResponse.json(
        { error: "vendorId is required" },
        { status: 400 }
      );
    }

    const vendor = await prisma.vendor.findUnique({
      where: { id: vendorId },
      select: { id: true, name: true, organizationId: true },
    });

    if (!vendor) {
      return NextResponse.json(
        { error: "Vendor not found" },
        { status: 404 }
      );
    }

    let template = null;
    let templateId: number | null = null;

    if (templateIdRaw !== null && !Number.isNaN(templateIdRaw)) {
      template = await prisma.assessmentTemplate.findUnique({
        where: { id: templateIdRaw },
        select: { id: true, name: true },
      });

      if (!template) {
        return NextResponse.json(
          { error: "Template not found" },
          { status: 404 }
        );
      }

      templateId = template.id;
    }

    const defaultTitle =
      template && vendor
        ? `${template.name} – ${vendor.name}`
        : template
        ? `${template.name} – Assessment`
        : `Assessment for ${vendor.name}`;

    const finalTitle = title || defaultTitle;

    const result = await prisma.$transaction(async (tx) => {
      const assessment = await tx.assessment.create({
        data: {
          organizationId: vendor.organizationId,
          vendorId: vendor.id,
          templateId,
          status: "DRAFT",
          title: finalTitle,
          dueAt,
        },
      });

      if (templateId) {
        const questions = await tx.assessmentQuestion.findMany({
          where: { templateId },
          select: { id: true },
        });

        if (questions.length > 0) {
          await tx.assessmentAnswer.createMany({
            data: questions.map((q) => ({
              assessmentId: assessment.id,
              questionId: q.id,
              value: "", // empty string as canonical placeholder
            })),
            skipDuplicates: true,
          });
        }
      }

      return assessment;
    });

    // refetch with vendor + template for response payload
    const created = await prisma.assessment.findUnique({
      where: { id: result.id },
      include: {
        vendor: { select: { id: true, name: true } },
        template: { select: { id: true, name: true } },
      },
    });

    if (!created) {
      return NextResponse.json(
        { error: "Failed to load newly created assessment" },
        { status: 500 }
      );
    }

    const payload = {
      id: created.id,
      title: created.title,
      status: created.status,
      vendorId: created.vendorId,
      vendorName: created.vendor?.name ?? "Unknown vendor",
      templateId: created.templateId,
      templateName: created.template?.name ?? null,
      createdAt: created.createdAt.toISOString(),
      updatedAt: created.updatedAt.toISOString(),
      dueAt: created.dueAt ? created.dueAt.toISOString() : null,
      completedAt: created.completedAt
        ? created.completedAt.toISOString()
        : null,
    };

    return NextResponse.json(payload, { status: 201 });
  } catch (error) {
    console.error("Error creating assessment run:", error);
    return NextResponse.json(
      { error: "Failed to create assessment run" },
      { status: 500 }
    );
  }
}
