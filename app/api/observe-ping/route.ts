// app/api/observe-ping/route.ts
import { NextResponse } from 'next/server';

export async function GET() {
  // Simple health-check style endpoint with no Sentry dependency
  return NextResponse.json({ ok: true, source: 'truvern-observe-ping' });
}
