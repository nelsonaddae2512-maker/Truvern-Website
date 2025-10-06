
import { NextResponse } from "next/server";
import { getServerSession } from "next-auth";
import { authOptions } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
type OrgIdRow = { organizationId: string | number };

export async function GET(){
  const session = await getServerSession(authOptions);
  const me = session?.user as any;
  if(!me?.email) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    // Find all orgs the reviewer belongs to

  const memberships: Pick<Membership, "organizationId">[] =
    await prisma.membership.findMany({
      where: { user: { email: me.email } },
      select: { organizationId: true },
    });

  const orgIds = memberships.map(({ organizationId }) => organizationId);
  if(orgIds.length === 0) return NextResponse.json({ items: [] });
  // Evidence rows for vendors in those orgs, newest first
  const items = await prisma.evidence.findMany({
    where: { vendor: { organizationId: { in: orgIds } }, status: { in: ["pending","rejected"] } },
    orderBy: { createdAt: "desc" },
    select: { id:true, vendorId:true, questionId:true, url:true, reviewerNote:true, status:true, createdAt:true,
      vendor: { select: { name: true } }
    }
  });
  return NextResponse.json({ items });
}
