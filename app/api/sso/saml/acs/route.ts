import prisma from "@/lib/db";





import { NextResponse } from "next/server";


import { randomUUID } from "crypto"


export const runtime = "nodejs"


export const dynamic = "force-dynamic";





type Org = { id: string; name: string; plan?: string; seats?: number }


export async function POST(req: Request) {


  try {


    const { domain } = await req.json();


    const name = `${domain} Org (SSO)`;





    let org = await prisma.organization.findFirst({ where: { name } });


    if (!org) {


      org = await prisma.organization.create({


        data: {


          id: randomUUID(),


          name,


          plan: "free",


          seats: 1,




        },


      });


    }





    return NextResponse.json({ success: true, org });


  }
catch (err) {
  // Normalize unknown error to a string
  const _errMsg =
    err instanceof Error
      ? err.message
      : (typeof err === 'string' ? err : (() => { try { return JSON.stringify(err); } catch { return 'Unknown error'; } })());
  try { console.error(err); } catch {}
  return NextResponse.json({ success: false, error: _errMsg }, { status: 500 });
}


}