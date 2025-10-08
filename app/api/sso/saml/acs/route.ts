export const runtime = "nodejs";
export const dynamic = "force-dynamic";

import { NextResponse } from "next/server";

type Org = { id: string; name: string; plan?: string; seats?: number };

export async function POST(req: Request) {
  try {
    const { email } = await req.json().catch(() => ({ email: "" }));
    if (!email) return NextResponse.json({ ok: false, error: "missing email" }, { status: 200 });
    const org = await getOrCreateOrg(email);
    return NextResponse.json({ ok: true, org }, { status: 200 });
  } catch {
    return NextResponse.json({ ok: false, error: "internal" }, { status: 200 });
  }
}

async function getOrCreateOrg(email: string): Promise<Org> {
  const { prisma } = await import("@/lib/prisma");

  const domain = email.split("@")[1]?.toLowerCase() || "unknown";
  const name = `${domain} Org (SSO)`;

  let org = await prisma.organization.findFirst({ where: { name } });
  if (!org) {
    org = await prisma.organization.create({ data: { name, plan: "pro", seats: 9999 } });
  }
  return { id: String(org.id), name: org.name, plan: (org as any).plan, seats: (org as any).seats };
}