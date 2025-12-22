import prisma from "@/lib/prisma";

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
    await prisma.$queryRaw`SELECT 1`;
    steps.dbPingMs = msSince(t1);

    steps.totalMs = msSince(t0);
    return Response.json({ ok: true, steps }, { status: 200 });
  } catch (e: any) {
    steps.totalMs = msSince(t0);
    return Response.json(
      {
        ok: false,
        steps,
        error: e?.message ?? String(e),
        name: e?.name,
      },
      { status: 500 }
    );
  }
}
