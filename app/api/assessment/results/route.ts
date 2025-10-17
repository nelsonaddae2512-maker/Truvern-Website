import { NextResponse } from 'next/server'
import { prisma } from '@/src/lib/db'
import { computeScore } from '@/src/lib/scoring'

export async function GET(req: Request) {
  try {
    const { searchParams } = new URL(req.url)
    const id = searchParams.get('id')
    if (!id) return NextResponse.json({ ok:false, error:'MISSING_ID' }, { status:400 })
    const rec = await prisma.assessmentSubmission.findUnique({ where: { id } })
    if (!rec) return NextResponse.json({ ok:false, error:'NOT_FOUND' }, { status:404 })
    const { score, tier } = computeScore(rec.answersJson)
    return NextResponse.json({ ok:true, submission: rec, score, tier })
  } catch (e) {
    console.error(e)
    return NextResponse.json({ ok:false, error:'RESULTS_FAILED' }, { status:500 })
  }
}
