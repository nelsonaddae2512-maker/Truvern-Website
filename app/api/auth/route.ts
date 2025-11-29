export const runtime = 'nodejs';
import { NextResponse } from 'next/server';
export async function GET(_req: Request) {
  return NextResponse.json({ ok: true, route: '/app/api/auth' });
}
