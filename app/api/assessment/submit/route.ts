import { NextResponse } from 'next/server'
import { prisma } from '@/src/lib/db'

export async function POST(req: Request) {
  try {
    const form = await req.formData()
    const companyName = String(form.get('companyName') ?? '')
    const contactEmail = String(form.get('contactEmail') ?? '')
    const answersJson = String(form.get('answersJson') ?? '[]')
    const rec = await prisma.assessmentSubmission.create({
      data: { companyName, contactEmail, answersJson },
    })
    return NextResponse.redirect(new URL(`/assessment/results?id=${rec.id}`, req.url))
  } catch (err) {
    console.error(err)
    return NextResponse.json({ ok: false, error: 'SUBMIT_FAILED' }, { status: 500 })
  }
}
