// app/api/assessment-templates/[id]/structure/route.ts
import { NextResponse } from "next/server";
import prisma from "@/lib/prisma";

type RouteParams = {
  params: { id: string };
};

type IncomingQuestion = {
  id?: number;
  prompt: string;
  helpText?: string;
  kind: "YES_NO" | "TEXT" | "SELECT" | "MULTI_SELECT" | "NUMBER";
  required: boolean;
  weight?: number | null;
  key?: string;
  orderIndex: number;
  options: string[];
};

type IncomingSection = {
  id?: number;
  title: string;
  description?: string;
  order: number;
  weight?: number | null;
  questions: IncomingQuestion[];
};

export async function POST(req: Request, { params }: RouteParams) {
  const templateId = Number(params.id);
  if (!templateId || Number.isNaN(templateId)) {
    return NextResponse.json({ error: "Invalid id" }, { status: 400 });
  }

  const body = await req.json();
  const sections: IncomingSection[] = body.sections ?? [];

  try {
    await prisma.$transaction(async (tx) => {
      // Remove existing sections & questions for this template
      await tx.assessmentQuestion.deleteMany({
        where: { templateId },
      });
      await tx.assessmentSection.deleteMany({
        where: { templateId },
      });

      for (const section of sections) {
        const createdSection = await tx.assessmentSection.create({
          data: {
            templateId,
            title: section.title || "Untitled section",
            description: section.description ?? null,
            order: section.order ?? 0,
            weight: section.weight ?? null,
          },
        });

        for (const question of section.questions) {
          // Map UI kind -> legacy QuestionType + richType + options JSON
          let type: "BOOLEAN" | "TEXT" | "MULTI_CHOICE" = "TEXT";
          let richType:
            | "TEXT"
            | "YES_NO"
            | "SELECT"
            | "MULTI_SELECT"
            | "NUMBER"
            | null = null;

          switch (question.kind) {
            case "YES_NO":
              type = "BOOLEAN";
              richType = "YES_NO";
              break;
            case "TEXT":
              type = "TEXT";
              richType = "TEXT";
              break;
            case "SELECT":
              type = "MULTI_CHOICE";
              richType = "SELECT";
              break;
            case "MULTI_SELECT":
              type = "MULTI_CHOICE";
              richType = "MULTI_SELECT";
              break;
            case "NUMBER":
              type = "TEXT";
              richType = "NUMBER";
              break;
          }

          const optionsJson =
            question.options && question.options.length > 0
              ? { options: question.options }
              : null;

          await tx.assessmentQuestion.create({
            data: {
              templateId,
              sectionId: createdSection.id,
              orderIndex: question.orderIndex ?? 0,
              text: question.prompt || "",
              helpText: question.helpText ?? null,
              type,
              richType,
              required: question.required ?? false,
              // keep weight as Int for now; round if needed
              weight:
                typeof question.weight === "number"
                  ? Math.round(question.weight)
                  : null,
              key: question.key ?? null,
              options: optionsJson,
            },
          });
        }
      }
    });

    return NextResponse.json({ ok: true });
  } catch (err) {
    console.error(
      "Error saving assessment template structure for template",
      templateId,
      err
    );
    return NextResponse.json(
      { error: "Failed to save template structure" },
      { status: 500 }
    );
  }
}
