// app/assessment-templates/page.tsx
import prisma from "@/lib/prisma";
import AssessmentTemplateManager from "@/components/assessment-template-manager";

export const metadata = {
  title: "Assessment Templates – Truvern",
  description:
    "Create and manage reusable assessment templates for your vendor risk program.",
};

export default async function AssessmentTemplatesPage() {
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

  const safeTemplates = templates.map((t) => ({
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

  return (
    <main className="relative max-w-6xl mx-auto px-4 lg:px-6 py-12 lg:py-16">
      {/* Soft background glows */}
      <div className="pointer-events-none absolute inset-x-0 -top-32 -z-10 h-64 bg-[radial-gradient(circle_at_top,_rgba(45,212,191,0.25),transparent_60%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 -z-10 h-64 bg-[radial-gradient(circle_at_bottom,_rgba(56,189,248,0.20),transparent_60%)]" />

      {/* Accent line */}
      <div className="h-px w-full bg-gradient-to-r from-emerald-400/80 via-cyan-400/70 to-violet-500/70 mb-6" />

      <AssessmentTemplateManager initialTemplates={safeTemplates} />
    </main>
  );
}
