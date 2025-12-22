import { auth } from "@clerk/nextjs/server";
import { requireDbOrganization } from "@/lib/org-db";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function msSince(t0: bigint) {
  return Number((process.hrtime.bigint() - t0) / 1000000n);
}

export async function GET() {
  const t0 = process.hrtime.bigint();
  const steps: Record<string, number> = {};

  try {
    const t1 = process.hrtime.bigint();
    const a = auth();
    steps.clerkAuthMs = msSince(t1);

    const t2 = process.hrtime.bigint();
    // this is the common “hang point” if anything is looping or waiting
    const org = await requireDbOrganization();
    steps.requireOrgMs = msSince(t2);

    steps.totalMs = msSince(t0);
    return Response.json({ ok: true, steps, org: { id: org?.id, name: org?.name } });
  } catch (e: any) {
    steps.totalMs = msSince(t0);
    return Response.json(
      { ok: false, steps, name: e?.name, error: e?.message ?? String(e) },
      { status: 500 }
    );
  }
}
