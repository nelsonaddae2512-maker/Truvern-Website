import prisma from "../lib/prisma";

async function main() {
  console.log("Backfilling AssessmentQuestion.templateId…");

  const questions = await prisma.assessmentQuestion.findMany({
    where: {
      templateId: null,
      sectionId: { not: null },
    },
    select: {
      id: true,
      sectionId: true,
    },
  });

  console.log(`Found ${questions.length} questions to backfill`);

  for (const q of questions) {
    const section = await prisma.assessmentSection.findUnique({
      where: { id: q.sectionId! },
      select: { templateId: true },
    });

    if (!section?.templateId) continue;

    await prisma.assessmentQuestion.update({
      where: { id: q.id },
      data: { templateId: section.templateId },
    });
  }

  console.log("Backfill complete ✅");
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
