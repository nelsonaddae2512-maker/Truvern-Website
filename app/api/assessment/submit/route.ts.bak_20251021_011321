import prisma from "@/lib/db";

import { NextResponse } from 'next/server'

export async function POST(req: Request) {
  try {
    const form = await req.formData()
    const companyName = String(form.get('companyName') ?? '')
    const contactEmail = String(form.get('contactEmail') ?? '')
    const answersStr = String(form.get('answersJson') ?? '[]');
  let answersJson: any;
  try { answersJson = JSON.parse(answersStr); } catch { answersJson = []; }
    const rec = await prisma.assessmentSubmission.create({
      data: { companyName, contactEmail, answersJson },
    })
    return NextResponse.redirect(new URL(`/assessment/results?id=${rec.id}`, req.url))
  } catch (err) {
    console.error(err)
    return NextResponse.json({ ok: false, error: 'SUBMIT_FAILED' }, { status: 500 })
  }
}

