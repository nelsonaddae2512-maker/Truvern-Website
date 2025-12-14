// scripts/backfillEvidenceRequestLinks.ts
import prisma from "../lib/prisma";

async function main() {
  const reqs = await prisma.evidenceRequest.findMany({
    where: { evidenceId: { not: null } },
    select: { id: true, evidenceId: true, status: true },
  });

  let updated = 0;

  for (const r of reqs) {
    const evId = r.evidenceId!;
    // Only set if not already linked
    const ev = await prisma.evidence.findUnique({
      where: { id: evId },
      select: { id: true, evidenceRequestId: true },
    });

    if (!ev) continue;
    if (ev.evidenceRequestId === r.id) continue;

    await prisma.evidence.update({
      where: { id: evId },
      data: { evidenceRequestId: r.id },
    });

    // Optional: set submittedAt if request is already beyond OPEN
    if (r.status !== ("OPEN" as any)) {
      await prisma.evidenceRequest.update({
        where: { id: r.id },
        data: { submittedAt: new Date() } as any,
      });
    }

    updated++;
  }

  console.log(`Backfill complete. Linked ${updated} evidence rows.`);
}

main()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
