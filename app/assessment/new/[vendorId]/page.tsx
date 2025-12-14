// app/assessment/new/[vendorId]/page.tsx
import prisma from "@/lib/prisma";
import { redirect } from "next/navigation";

export const runtime = "nodejs";

type ParamsPromise = Promise<{ vendorId: string }>;

export default async function NewAssessmentForVendorPage({
  params,
}: {
  params: ParamsPromise;
}) {
  const { vendorId } = await params;
  const vid = Number(vendorId);

  if (!Number.isFinite(vid)) {
    redirect("/vendors");
  }

  const vendor = await prisma.vendor.findUnique({
    where: { id: vid },
    select: { id: true, organizationId: true, name: true },
  });

  if (!vendor) {
    redirect("/vendors");
  }

  // Pick a template if available: prefer org template, else global template.
  const template =
    (await prisma.assessmentTemplate.findFirst({
      where: { organizationId: vendor.organizationId, isActive: true },
      orderBy: { updatedAt: "desc" },
      select: { id: true, name: true },
    })) ??
    (await prisma.assessmentTemplate.findFirst({
      where: { organizationId: null, isActive: true },
      orderBy: { updatedAt: "desc" },
      select: { id: true, name: true },
    }));

  const created = await prisma.assessment.create({
    data: {
      organizationId: vendor.organizationId,
      vendorId: vendor.id,
      templateId: template?.id ?? null,
      status: "IN_PROGRESS",
      title: template?.name ? `${vendor.name} — ${template.name}` : `${vendor.name} — Assessment`,
    },
    select: { id: true },
  });

  redirect(`/assessment/runs/${created.id}`);
}
