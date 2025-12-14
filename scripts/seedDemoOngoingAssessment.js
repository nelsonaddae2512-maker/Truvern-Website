/* scripts/seedDemoOngoingAssessment.js */
const { PrismaClient } = require("@prisma/client");

const prisma = new PrismaClient();

function nowISO() {
  return new Date().toISOString();
}

function isUnknownArgError(e, field) {
  const msg = String(e?.message || "");
  return msg.includes(`Unknown argument \`${field}\``);
}

async function createWithRetryUnknownArgs(createFn, data, removableKeys = []) {
  // Try creating, and if Prisma complains about an unknown argument, remove it and retry.
  let current = { ...data };

  for (let attempt = 0; attempt < 8; attempt++) {
    try {
      return await createFn({ data: current });
    } catch (e) {
      // Remove the first key that Prisma says is unknown
      let removed = false;

      for (const key of removableKeys) {
        if (key in current && isUnknownArgError(e, key)) {
          delete current[key];
          removed = true;
          break;
        }
      }

      if (removed) continue;
      throw e; // not an unknown-arg problem; surface it
    }
  }

  // Should never reach here
  return await createFn({ data: current });
}

async function main() {
  // ---- Find or create a vendor ----
  const vendor =
    (await prisma.vendor.findFirst({ orderBy: { id: "asc" } }).catch(() => null)) ||
    (await prisma.vendor
      .create({
        data: {
          name: "Demo Vendor (Ongoing Assessment)",
          riskScore: 72,
          summary: "Seeded demo vendor to validate assessment runs end-to-end.",
        },
      })
      .catch(async () => {
        return prisma.vendor.create({
          data: { name: "Demo Vendor (Ongoing Assessment)" },
        });
      }));

  // ---- Detect which models exist ----
  const anyPrisma = prisma;
  const has = (model) => typeof anyPrisma[model]?.create === "function";

  const hasTemplate = has("assessmentTemplate");
  const hasTemplateSection = has("assessmentTemplateSection");
  const hasTemplateQuestion = has("assessmentTemplateQuestion");

  const hasAssessment = has("assessment");
  const hasAssessmentRun = has("assessmentRun");

  const hasAssessmentQuestion = has("assessmentQuestion");
  const hasAssessmentAnswer = has("assessmentAnswer");

  // ---- Create / reuse template + sections (best effort) ----
  let template = null;
  let secA = null;
  let secB = null;

  if (hasTemplate) {
    template =
      (await anyPrisma.assessmentTemplate
        .findFirst({
          where: { title: "Truvern Demo Template" },
          orderBy: { id: "desc" },
        })
        .catch(() => null)) ||
      (await anyPrisma.assessmentTemplate
        .create({
          data: {
            title: "Truvern Demo Template",
            description: "Seeded template for validating runs, questions, and scoring UX.",
          },
        })
        .catch(() => null));

    if (template && hasTemplateSection) {
      secA =
        (await anyPrisma.assessmentTemplateSection
          .findFirst({
            where: { templateId: template.id, title: "Security Basics" },
            orderBy: { id: "asc" },
          })
          .catch(() => null)) ||
        (await anyPrisma.assessmentTemplateSection
          .create({
            data: { templateId: template.id, title: "Security Basics", order: 1 },
          })
          .catch(() => null));

      secB =
        (await anyPrisma.assessmentTemplateSection
          .findFirst({
            where: { templateId: template.id, title: "Evidence & Compliance" },
            orderBy: { id: "asc" },
          })
          .catch(() => null)) ||
        (await anyPrisma.assessmentTemplateSection
          .create({
            data: { templateId: template.id, title: "Evidence & Compliance", order: 2 },
          })
          .catch(() => null));
    }

    // Optional: seed template questions if that model exists
    if (template && hasTemplateQuestion) {
      const tqs = [
        {
          sectionId: secA?.id,
          order: 1,
          title: "MFA enforced?",
          prompt: "Is multi-factor authentication enforced for all staff?",
          type: "BOOLEAN",
          weight: 2,
          points: 10,
        },
        {
          sectionId: secA?.id,
          order: 2,
          title: "Encryption at rest?",
          prompt: "Is encryption at rest enabled for production data stores?",
          type: "BOOLEAN",
          weight: 2,
          points: 10,
        },
        {
          sectionId: secB?.id,
          order: 1,
          title: "SOC 2 report available?",
          prompt: "Do you have a current SOC 2 Type II report?",
          type: "BOOLEAN",
          weight: 3,
          points: 15,
        },
        {
          sectionId: secB?.id,
          order: 2,
          title: "Incident response policy?",
          prompt: "Provide or confirm existence of an incident response policy.",
          type: "TEXT",
          weight: 1,
          points: 5,
        },
      ];

      for (const q of tqs) {
        const exists = await anyPrisma.assessmentTemplateQuestion
          .findFirst({ where: { templateId: template.id, title: q.title } })
          .catch(() => null);
        if (exists) continue;

        await anyPrisma.assessmentTemplateQuestion
          .create({
            data: {
              templateId: template.id,
              templateSectionId: q.sectionId ?? undefined,
              order: q.order,
              title: q.title,
              prompt: q.prompt,
              type: q.type,
              weight: q.weight,
              points: q.points,
            },
          })
          .catch(() => null);
      }
    }
  }

  // ---- Create a run (Assessment or AssessmentRun) ----
  const runModel = hasAssessmentRun ? "assessmentRun" : hasAssessment ? "assessment" : null;
  if (!runModel) {
    throw new Error(
      "No assessment model found. Expected prisma.assessment or prisma.assessmentRun in your schema."
    );
  }

  const existingRun = await anyPrisma[runModel]
    .findFirst({
      where: { vendorId: vendor.id, status: "IN_PROGRESS" },
      orderBy: { id: "desc" },
    })
    .catch(() => null);

  const run =
    existingRun ||
    (await anyPrisma[runModel]
      .create({
        data: {
          vendorId: vendor.id,
          title: "Ongoing Security Review (Seeded)",
          status: "IN_PROGRESS",
          startedAt: new Date(),
          ...(template?.id ? { templateId: template.id } : {}),
        },
      })
      .catch(async () => {
        // fallback minimal
        const data = { vendorId: vendor.id, status: "IN_PROGRESS" };
        if (template?.id) data.templateId = template.id;
        return anyPrisma[runModel].create({ data });
      }));

  // ---- Create questions (template-scoped schema safe) ----
  let questionIds = [];

  if (hasAssessmentQuestion) {
    // if any exist for this template, reuse them
    if (template?.id) {
      const existing = await anyPrisma.assessmentQuestion
        .findMany({
          where: { templateId: template.id },
          select: { id: true },
          take: 10,
        })
        .catch(() => []);

      if (existing?.length) {
        questionIds = existing.map((r) => r.id).filter(Boolean);
      }
    }

    if (questionIds.length === 0) {
      const qs = [
        {
          title: "MFA enforced?",
          prompt: "Is multi-factor authentication enforced for all staff?",
          type: "BOOLEAN",
          sectionId: secA?.id,
        },
        {
          title: "Encryption at rest?",
          prompt: "Is encryption at rest enabled for production data stores?",
          type: "BOOLEAN",
          sectionId: secA?.id,
        },
        {
          title: "SOC 2 report available?",
          prompt: "Do you have a current SOC 2 Type II report?",
          type: "BOOLEAN",
          sectionId: secB?.id,
        },
        {
          title: "Incident response policy?",
          prompt: "Provide or confirm existence of an incident response policy.",
          type: "TEXT",
          sectionId: secB?.id,
        },
      ];

      for (let i = 0; i < qs.length; i++) {
        const q = qs[i];

        // IMPORTANT: Always include orderIndex + text (because your schema requires them),
        // and then retry-remove if Prisma says they're unknown (future-proof).
        const base = {
          type: q.type,
          updatedAt: new Date(),

          // required in your schema
          orderIndex: i + 1,
          text: q.title || q.prompt || `Seeded question ${i + 1}`,

          // optional if present
          prompt: q.prompt,
          title: q.title,

          // template/section scope (optional if present)
          templateId: template?.id,
          sectionId: q.sectionId ?? undefined,
        };

        const created = await createWithRetryUnknownArgs(
          anyPrisma.assessmentQuestion.create.bind(anyPrisma.assessmentQuestion),
          base,
          [
            // removable keys if schema doesn't support them
            "templateId",
            "sectionId",
            "prompt",
            "title",

            // keep these removable too (future-proof)
            "orderIndex",
            "text",
            "updatedAt",
          ]
        );

        if (created?.id) questionIds.push(created.id);
      }
    }
  }

  // ---- Seed answers (run-scoped) ----
  if (hasAssessmentAnswer && questionIds.length) {
    const sample = questionIds.slice(0, Math.min(2, questionIds.length));

    for (const qid of sample) {
      const exists = await anyPrisma.assessmentAnswer
        .findFirst({ where: { assessmentId: run.id, questionId: qid } })
        .catch(() => null);
      if (exists) continue;

      // Many schemas require updatedAt; some accept createdAt; keep minimal + retry unknown args
      const base = {
        assessmentId: run.id,
        questionId: qid,
        value: qid === sample[0] ? true : "Drafted response (seeded).",
        updatedAt: new Date(),
      };

      await createWithRetryUnknownArgs(
        anyPrisma.assessmentAnswer.create.bind(anyPrisma.assessmentAnswer),
        base,
        ["updatedAt"]
      ).catch(() => null);
    }
  }

  console.log("✅ Demo ongoing assessment seeded");
  console.log(`Vendor: #${vendor.id} ${vendor.name}`);
  console.log(`Run:    #${run.id} status=${run.status} (model=${runModel})`);
  console.log(`Time:   ${nowISO()}`);
  console.log("");
  console.log("Open the run:");
  console.log(`→ /assessment/runs/${run.id}`);
}

main()
  .catch((e) => {
    console.error("❌ Seed failed:", e);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
