import prisma from "@/lib/prisma";

export type ActivityCursor = { createdAt: string; id: number };

export function encodeCursor(c: ActivityCursor) {
  return Buffer.from(JSON.stringify(c), "utf8").toString("base64");
}

export function decodeCursor(raw?: string | null): ActivityCursor | null {
  if (!raw) return null;
  try {
    const json = Buffer.from(raw, "base64").toString("utf8");
    const obj = JSON.parse(json);
    const id = Number(obj?.id);
    const createdAt = String(obj?.createdAt ?? "");
    if (!Number.isFinite(id) || !createdAt) return null;
    return { id, createdAt };
  } catch {
    return null;
  }
}

export async function fetchActivityEvents(opts: {
  organizationId: number;
  vendorId?: number | null;
  take: number;
  cursor?: ActivityCursor | null;
}) {
  const take = Math.max(1, Math.min(100, opts.take || 25));
  const cursor = opts.cursor ?? null;

  const where: any = { organizationId: opts.organizationId };
  if (opts.vendorId != null) where.vendorId = opts.vendorId;

  if (cursor) {
    where.AND = [
      {
        OR: [
          { createdAt: { lt: new Date(cursor.createdAt) } },
          {
            AND: [
              { createdAt: { equals: new Date(cursor.createdAt) } },
              { id: { lt: cursor.id } },
            ],
          },
        ],
      },
    ];
  }

  const rows = await prisma.activityEvent.findMany({
    where,
    orderBy: [{ createdAt: "desc" }, { id: "desc" }],
    take: take + 1,
    select: {
      id: true,
      organizationId: true,
      vendorId: true,
      type: true,
      title: true,
      description: true,
      metadata: true,
      createdAt: true,
      actorUserId: true,
      actorName: true,
      actorEmail: true,
      vendor: { select: { id: true, name: true, slug: true } },
    },
  });

  const hasMore = rows.length > take;
  const items = hasMore ? rows.slice(0, take) : rows;

  const nextCursor = hasMore
    ? encodeCursor({
        id: items[items.length - 1].id,
        createdAt: items[items.length - 1].createdAt.toISOString(),
      })
    : null;

  return {
    items: items.map((r) => ({ ...r, createdAt: r.createdAt.toISOString() })),
    nextCursor,
  };
}