import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const runtime = 'nodejs';
export const dynamic = 'force-dynamic';

type RouteContext = { params: { id: string } };

export async function GET(_req: Request, { params }: RouteContext) {
  const id = Number(params.id);

  if (!Number.isInteger(id) || id <= 0) {
    return NextResponse.json(
      { error: 'Invalid evidence id', details: params.id },
      { status: 400 }
    );
  }

  try {
    const evidence = await prisma.evidence.findUnique({
      where: { id }
    });

    if (!evidence) {
      return NextResponse.json(
        { error: 'Evidence not found', id },
        { status: 404 }
      );
    }

    return NextResponse.json({ evidence });
  } catch (err) {
    console.error('Evidence lookup failed', err);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
