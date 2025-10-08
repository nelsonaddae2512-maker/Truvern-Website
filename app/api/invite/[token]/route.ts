export const runtime = "nodejs";


export const dynamic = "force-dynamic";


import { NextResponse } from "next/server";


import type { NextRequest } from "next/server";





export async function GET(req: NextRequest, { params }: { params: { token: string } }){ const { prisma } = await import("@/lib/prisma"); 


  try {


    const token = String(params?.token || "").trim();


    if (!token) return NextResponse.json({ ok:false, error:"missing_token" }, { status:200 });





    const { prisma } = await import("@/lib/prisma");





    const invite = await prisma.pendingInvite.findFirst({


      where: { token, expiresAt: { gt: new Date() } },


      select: { id:true, email:true, organizationId:true, expiresAt:true }


    });





    if (!invite) return NextResponse.json({ ok:false, error:"invalid_or_expired" }, { status:200 });
  const role = "member"; // default role (invite has no role field)





    return NextResponse.json({ ok:true, invite }, { status:200 });


  } catch {


    return NextResponse.json({ ok:false, error:"internal" }, { status:200 });


  }


}