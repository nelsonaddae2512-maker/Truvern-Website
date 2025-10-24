import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'

export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const page = Number(searchParams.get('page') ?? '1')
  const pageSize = Math.min(Number(searchParams.get('pageSize') ?? '24'), 50)
  const verified = searchParams.get('verified')
  const q = searchParams.get('q')?.trim()

  const where: any = {}
  if (verified === 'true') where.verified = true
  if (q) where.name = { contains: q, mode: 'insensitive' }

  const [items, total] = await Promise.all([
    prisma.vendor.findMany({
      where,
      orderBy: [ { id: 'desc' } ],
      skip: (page - 1) * pageSize,
      take: pageSize,
      select: {
  id: true,
  name: true,
},
    }),
    prisma.vendor.count({ where }),
  ])

  return NextResponse.json({
    page, pageSize, total, items,
  })
}


