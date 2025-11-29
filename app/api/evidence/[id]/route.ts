// app/api/evidence/[id]/route.ts

import { NextResponse } from 'next/server';
import { prisma } from '@/lib/prisma';

export const runtime = 'nodejs';      // make sure Prisma runs in Node
export const dynamic = 'force-dynamic';

type RouteContext = {
  params: {
    id: string;
  };
};

export async function GET(_req: Request, { params }: RouteContext) {
  // Validate ID
  const id = Number(params.id);
  if (!Number.isInteger(id) || id <= 0) {
    return NextResponse.json(
      { error: 'Invalid evidence id', details: { id: params.id } },
      { status: 400 }
    );
  }

  try {
    const evidence = await prisma.evidence.findUnique({
      where: { id },
      // If you have a Vendor relation and want it:
      // include: { vendor: true },
    });

    if (!evidence) {
      return NextResponse.json(
        { error: 'Evidence not found', details: { id } },
        { status: 404 }
      );
    }

    return NextResponse.json({ evidence });
  } catch (err: unknown) {
    console.error('Error in /api/evidence/[id]', err);
    return NextResponse.json(
      {
        error: 'Internal server error',
      },
      { status: 500 }
    );
  }
}
