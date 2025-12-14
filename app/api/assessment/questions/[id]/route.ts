import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function getQuestionIdFromUrl(req: NextRequest): number | null {
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

export async function PATCH(req: NextRequest) {
  try {
    const id = getQuestionIdFromUrl(req);
    if (id === null) {
      return NextResponse.json(
        { error: "Invalid question id" },
        { status: 400 }
      );
    }

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

    if (!text) {
      return NextResponse.json(
        { error: "Question text is required" },
        { status: 400 }
      );
    }

    const data: any = {
      text,
      helpText: description,
      description,
      type,
      category,
    };

    // Optional fields for template builder
    if (body.templateId !== undefined) {
      if (body.templateId === null) {
        data.templateId = null;
      } else {
        const tId = Number(body.templateId);
        if (!Number.isNaN(tId)) data.templateId = tId;
      }
    }

    if (body.sectionId !== undefined) {
      if (body.sectionId === null) {
        data.sectionId = null;
      } else {
        const sId = Number(body.sectionId);
        if (!Number.isNaN(sId)) data.sectionId = sId;
      }
    }

    if (typeof body.required === "boolean") {
      data.required = body.required;
    }

    if (body.weight !== undefined) {
      if (body.weight === null) {
        data.weight = null;
      } else if (typeof body.weight === "number") {
        data.weight = body.weight;
      }
    }

    if (body.orderIndex !== undefined) {
      const oi = Number(body.orderIndex);
      if (!Number.isNaN(oi)) {
        data.orderIndex = oi;
      }
    }

    const updated = await prisma.assessmentQuestion.update({
      where: { id },
      data,
    });

    const payload = {
      ...updated,
      createdAt: updated.createdAt.toISOString(),
      updatedAt: updated.updatedAt.toISOString(),
    };

    return NextResponse.json(payload);
  } catch (error: any) {
    console.error("Error updating assessment question:", error);
    return NextResponse.json(
      { error: "Failed to update question" },
      { status: 500 }
    );
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const id = getQuestionIdFromUrl(req);
    if (id === null) {
      return NextResponse.json(
        { error: "Invalid question id" },
        { status: 400 }
      );
    }

    await prisma.assessmentQuestion.delete({
      where: { id },
    });

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error("Error deleting assessment question:", error);
    return NextResponse.json(
      { error: "Failed to delete question" },
      { status: 500 }
    );
  }
}
