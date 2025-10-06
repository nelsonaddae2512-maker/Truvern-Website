
import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";

export async function GET(){
  const session = await getServerSession(authOptions);
  const me = session?.user as any;
  if(!me?.organizationId) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });

  const now = new Date();
  const from30 = new Date(now.getTime() - 30*24*60*60*1000);
  const rows = await prisma.usageEvent.findMany({
    where: { organizationId: me.organizationId, createdAt: { gte: from30 } },
    orderBy: { createdAt: "asc" },
    take: 5000,
  });

  const byDay: Record<string, Record<string, number>> = {};
  for(const r of rows){
    const d = new Date(r.createdAt);
    const key = `${d.getFullYear()}-${(d.getMonth()+1).toString().padStart(2,"0")}-${d.getDate().toString().padStart(2,"0")}`;
    byDay[key] ||= {};
    byDay[key][r.type] = (byDay[key][r.type] || 0) + r.count;
  }
  const totals: Record<string, number> = {};
  for(const r of rows){ totals[r.type] = (totals[r.type] || 0) + r.count; }

  return NextResponse.json({ byDay, totals });
}
