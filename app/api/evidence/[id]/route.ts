// app/api/evidence/[id]/route.ts
// Safe stub: keeps API alive without touching Prisma.
// Your UI now uses fileUrl directly for downloads, so this
// endpoint is only for diagnostics / future expansion.

import { NextResponse } from 'next/server';

export const runtime = 'edge';
export const dynamic = 'force-dynamic';

type RouteContext = {
  params: {
    id: string;
  };
};

export async function GET(_req: Request, { params }: RouteContext) {
  const id = params.id ?? '';

  if (!/^[0-9]+$/.test(id)) {
    return NextResponse.json(
      {
        ok: false,
        error: 'Invalid evidence id',
        id,
      },
      { status: 400 }
    );
  }

  // For now we just return a simple stub response.
  // Real evidence metadata is loaded elsewhere (e.g. from vendor detail page).
  return NextResponse.json(
    {
      ok: true,
      id: Number(id),
      message:
        'Evidence API stub is alive. Downloads are served via fileUrl on the vendor page.',
    },
    { status: 200 }
  );
}
