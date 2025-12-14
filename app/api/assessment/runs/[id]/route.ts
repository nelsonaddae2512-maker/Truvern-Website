import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function getRunIdFromUrl(req: NextRequest): number | null {
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

// GET /api/assessment/runs/:id
export async function GET(req: NextRequest) {
  try {
    const id = getRunIdFromUrl(req);
    if (id === null) {
      return NextResponse.json(
        { error: "Invalid assessment id" },
        { status: 400 }
      );
    }

    const assessment = await prisma.assessment.findUnique({
      where: { id },
      include: {
        vendor: { select: { id: true, name: true } },
        template: { select: { id: true, name: true } },
      },
    });

    if (!assessment) {
      return NextResponse.json(
        { error: "Assessment not found" },
        { status: 404 }
      );
    }

    const payload = {
      id: assessment.id,
      title: assessment.title,
      status: assessment.status,
      vendorId: assessment.vendorId,
      vendorName: assessment.vendor?.name ?? "Unknown vendor",
      templateId: assessment.templateId,
      templateName: assessment.template?.name ?? null,
      dueAt: assessment.dueAt
        ? assessment.dueAt.toISOString()
        : null,
      completedAt: assessment.completedAt
        ? assessment.completedAt.toISOString()
        : null,
      createdAt: assessment.createdAt.toISOString(),
      updatedAt: assessment.updatedAt.toISOString(),
      score: assessment.score,
      confidentialityScore: assessment.confidentialityScore,
      integrityScore: assessment.integrityScore,
      availabilityScore: assessment.availabilityScore,
    };

    return NextResponse.json(payload);
  } catch (error) {
    console.error("Error loading assessment run:", error);
    return NextResponse.json(
      { error: "Failed to load assessment run" },
      { status: 500 }
    );
  }
}

// PATCH /api/assessment/runs/:id
// Body: { title?, status?, dueAt?, completedAt? }
export async function PATCH(req: NextRequest) {
  try {
    const id = getRunIdFromUrl(req);
    if (id === null) {
      return NextResponse.json(
        { error: "Invalid assessment id" },
        { status: 400 }
      );
    }

    const body = await req.json();
    const data: any = {};

    if (typeof body.title === "string") {
      data.title = body.title.trim() || null;
    }

    if (typeof body.status === "string") {
      data.status = body.status;
      if (body.status === "COMPLETED" && !body.completedAt) {
        data.completedAt = new Date();
      }
    }

    if (typeof body.dueAt === "string" && body.dueAt.trim()) {
      const d = new Date(body.dueAt);
      if (!Number.isNaN(d.getTime())) {
        data.dueAt = d;
      }
    }

    if (typeof body.completedAt === "string" && body.completedAt.trim()) {
      const c = new Date(body.completedAt);
      if (!Number.isNaN(c.getTime())) {
        data.completedAt = c;
      }
    }

    const updated = await prisma.assessment.update({
      where: { id },
      data,
      include: {
        vendor: { select: { id: true, name: true } },
        template: { select: { id: true, name: true } },
      },
    });

    const payload = {
      id: updated.id,
      title: updated.title,
      status: updated.status,
      vendorId: updated.vendorId,
      vendorName: updated.vendor?.name ?? "Unknown vendor",
      templateId: updated.templateId,
      templateName: updated.template?.name ?? null,
      dueAt: updated.dueAt ? updated.dueAt.toISOString() : null,
      completedAt: updated.completedAt
        ? updated.completedAt.toISOString()
        : null,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
      score: updated.score,
      confidentialityScore: updated.confidentialityScore,
      integrityScore: updated.integrityScore,
      availabilityScore: updated.availabilityScore,
    };

    return NextResponse.json(payload);
  } catch (error) {
    console.error("Error updating assessment run:", error);
    return NextResponse.json(
      { error: "Failed to update assessment run" },
      { status: 500 }
    );
  }
}

// DELETE /api/assessment/runs/:id
export async function DELETE(req: NextRequest) {
  try {
    const id = getRunIdFromUrl(req);
    if (id === null) {
      return NextResponse.json(
        { error: "Invalid assessment id" },
        { status: 400 }
      );
    }

    await prisma.$transaction(async (tx) => {
      await tx.assessmentAnswer.deleteMany({
        where: { assessmentId: id },
      });
      await tx.assessment.delete({
        where: { id },
      });
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error("Error deleting assessment run:", error);
    return NextResponse.json(
      { error: "Failed to delete assessment run" },
      { status: 500 }
    );
  }
}
