import { NextRequest, NextResponse } from "next/server";
import prisma from "@/lib/prisma";

function getRunIdFromUrl(req: NextRequest): number | null {
  try {
    const url = new URL(req.url);
    const segments = url.pathname.split("/").filter(Boolean);
    // .../runs/:id/runner
    const runsIndex = segments.indexOf("runs") + 1;
    const raw = segments[runsIndex];
    const id = Number.parseInt(raw, 10);
    if (Number.isNaN(id)) return null;
    return id;
  } catch {
    return null;
  }
}

export async function GET(req: NextRequest) {
  try {
    const runId = getRunIdFromUrl(req);
    if (runId === null) {
      return NextResponse.json({ error: "Invalid run id" }, { status: 400 });
    }

    const run = await prisma.assessment.findUnique({
      where: { id: runId },
      include: {
        vendor: { select: { id: true, name: true } },
        template: { select: { id: true, name: true } },
      },
    });

    if (!run) {
      return NextResponse.json({ error: "Run not found" }, { status: 404 });
    }

    if (!run.templateId) {
      return NextResponse.json(
        {
          run: {
            id: run.id,
            title: run.title,
            status: run.status,
            vendorId: run.vendorId,
            vendorName: run.vendor?.name ?? "Unknown vendor",
            templateId: null,
            templateName: null,
            createdAt: run.createdAt.toISOString(),
            updatedAt: run.updatedAt.toISOString(),
          },
          sections: [],
          unsectioned: [],
        },
        { status: 200 }
      );
    }

    const templateId = run.templateId;

    const [sections, questions, answers] = await Promise.all([
      prisma.assessmentSection.findMany({
        where: { templateId },
        orderBy: { order: "asc" },
        select: {
          id: true,
          title: true,
          description: true,
          order: true,
          weight: true,
        },
      }),
      prisma.assessmentQuestion.findMany({
        where: { templateId },
        orderBy: { orderIndex: "asc" },
        select: {
          id: true,
          sectionId: true,
          orderIndex: true,
          text: true,
          helpText: true,
          description: true,
          category: true,
          type: true,
          required: true,
          weight: true,
          options: true,
        },
      }),
      prisma.assessmentAnswer.findMany({
        where: { assessmentId: runId },
        select: {
          id: true,
          questionId: true,
          value: true,
          valueJson: true,
          riskImpact: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
    ]);

    const answerByQuestionId = new Map<number, any>();
    for (const a of answers) {
      answerByQuestionId.set(a.questionId, {
        id: a.id,
        questionId: a.questionId,
        value: a.value ?? "",
        valueJson: a.valueJson,
        riskImpact: a.riskImpact,
        createdAt: a.createdAt.toISOString(),
        updatedAt: a.updatedAt ? a.updatedAt.toISOString() : null,
      });
    }

    // Build section buckets
    const sectionBuckets: Record<string, any> = {};
    for (const s of sections) {
      sectionBuckets[String(s.id)] = {
        id: s.id,
        title: s.title,
        description: s.description,
        order: s.order,
        weight: s.weight,
        questions: [],
      };
    }

    const unsectioned: any[] = [];

    for (const q of questions) {
      const a = answerByQuestionId.get(q.id) ?? null;

      const item = {
        id: q.id,
        sectionId: q.sectionId,
        orderIndex: q.orderIndex,
        text: q.text,
        helpText: q.helpText,
        description: q.description,
        category: q.category,
        type: q.type,
        required: q.required,
        weight: q.weight,
        options: q.options,
        answer: a,
      };

      if (q.sectionId && sectionBuckets[String(q.sectionId)]) {
        sectionBuckets[String(q.sectionId)].questions.push(item);
      } else {
        unsectioned.push(item);
      }
    }

    // Sort section questions
    Object.values(sectionBuckets).forEach((b: any) => {
      b.questions.sort((a: any, b2: any) => a.orderIndex - b2.orderIndex);
    });
    unsectioned.sort((a: any, b: any) => a.orderIndex - b.orderIndex);

    return NextResponse.json({
      run: {
        id: run.id,
        title: run.title,
        status: run.status,
        vendorId: run.vendorId,
        vendorName: run.vendor?.name ?? "Unknown vendor",
        templateId: run.templateId,
        templateName: run.template?.name ?? null,
        createdAt: run.createdAt.toISOString(),
        updatedAt: run.updatedAt.toISOString(),
      },
      sections: sections
        .slice()
        .sort((a, b) => a.order - b.order)
        .map((s) => sectionBuckets[String(s.id)]),
      unsectioned,
    });
  } catch (error) {
    console.error("Error loading runner payload:", error);
    return NextResponse.json(
      { error: "Failed to load runner payload" },
      { status: 500 }
    );
  }
}
