// app/api/authdebug/route.ts
import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

async function safeHeaders() {
  try {
    const mod = await import("next/headers");
    const h = mod.headers();
    return h;
  } catch {
    return null;
  }
}

async function safeCookies() {
  try {
    const mod = await import("next/headers");
    // Next 16: cookies() may be async in route handlers
    const c: any = await (mod as any).cookies();
    return c;
  } catch {
    return null;
  }
}

async function safeClerkAuth() {
  try {
    const mod = await import("@clerk/nextjs/server");
    const a = (mod as any).auth?.();
    return a ?? null;
  } catch (e: any) {
    return { __error: String(e?.message || e) };
  }
}

function pick(h: Headers | null, key: string) {
  try {
    return h?.get(key) ?? null;
  } catch {
    return null;
  }
}

export async function GET() {
  const h = await safeHeaders();
  const ck: any = await safeCookies();
  const a: any = await safeClerkAuth();

  const cookieNames: string[] = (() => {
    try {
      const all = typeof ck?.getAll === "function" ? ck.getAll() : [];
      return Array (all).map((x: any) => x?.name).filter(Boolean);
    } catch {
      return [];
    }
  })();

  const clerkCookieNames = cookieNames.filter((n) =>
    String(n).toLowerCase().includes("clerk")
  );

  return NextResponse.json({
    ok: true,
    auth: {
      userId: a?.userId ?? null,
      orgId: a?.orgId ?? null,
      sessionId: a?.sessionId ?? null,
      error: a?.__error ?? null,
    },
    cookies: {
      total: cookieNames.length,
      clerkCookieNames,
      hasAnyCookieHeader: !!pick(h, "cookie"),
    },
    requestHeaders: {
      host: pick(h, "host"),
      "user-agent": pick(h, "user-agent"),
      "x-forwarded-host": pick(h, "x-forwarded-host"),
      "x-forwarded-proto": pick(h, "x-forwarded-proto"),
      "x-clerk-auth-status": pick(h, "x-clerk-auth-status"),
      "x-clerk-auth-reason": pick(h, "x-clerk-auth-reason"),
      "x-clerk-request-id": pick(h, "x-clerk-request-id"),
    },
  });
}
