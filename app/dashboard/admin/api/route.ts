import { NextResponse } from 'next/server';
export async function GET(_req: Request) {
  return NextResponse.json({ ok: true, route: '/app/dashboard/admin/api/route.ts' });
}