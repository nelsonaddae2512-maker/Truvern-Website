import { computeDueAt } from "@/lib/issue-sla";

async function ensureIssue(params: {
  organizationId: number;
  vendorId: number;
  assessmentId: number;
  title: string;
  description?: string;
  severity?: "LOW" | "MEDIUM" | "HIGH" | "CRITICAL";
}) {
  const {
    organizationId,
    vendorId,
    assessmentId,
    title,
    description,
    severity = "MEDIUM",
  } = params;

  const existing = await prisma.issue.findFirst({
    where: {
      assessmentId,
      title,
      status: { in: ["OPEN", "IN_REVIEW"] as any },
    } as any,
    select: { id: true },
  });

  if (existing) return;

  const openedAt = new Date();
  const dueAt = computeDueAt(severity, openedAt);

  const created = await prisma.issue.create({
    data: {
      organizationId,
      vendorId,
      assessmentId,
      title,
      description,
      severity,
      status: "OPEN",
      openedAt,
      dueAt,
      events: {
        create: {
          type: "CREATED",
          payload: {
            source: "ASSESSMENT_SUBMIT",
            severity,
            title,
          },
        },
      },
    } as any,
  });

  return created;
}
