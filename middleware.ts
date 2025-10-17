import type { NextRequest } from 'next/server'
const WINDOW_MS = 60000
const LIMIT = 60
const hits = new Map<string,{count:number,ts:number}>()
export function middleware(req: NextRequest) {
  if (!req.nextUrl.pathname.startsWith('/api/assessment')) return
  const ip = req.ip ?? req.headers.get('x-forwarded-for') ?? 'unknown'
  const now = Date.now()
  const seen = hits.get(ip)
  if (!seen || now - seen.ts > WINDOW_MS) { hits.set(ip,{count:1,ts:now}); return }
  if (seen.count >= LIMIT) {
    return new Response(JSON.stringify({ ok:false, error:'RATE_LIMIT' }), { status: 429 })
  }
  seen.count++
}


export const config = {
  matcher: [
    '/dashboard/:path*',
    '/vendor/:path*',
    '/trust-network/:path*'
  ],
}
