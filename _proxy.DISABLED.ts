// proxy.ts
import { NextResponse, type NextRequest } from "next/server";
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/", // landing
  "/pricing(.*)",
  "/contact(.*)",
  "/trust(.*)",

  // auth
  "/auth(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",

  // org selection
  "/select-org(.*)",

  // invite accept flow
  "/invite(.*)",

  // health/diag
  "/api/health(.*)",
  "/api/whoami(.*)",
  "/api/envcheck(.*)",
  "/api/cookiedebug(.*)",
  "/api/authdebug(.*)",

  // static/public
  "/manifest.webmanifest",
  "/favicon.ico",
  "/robots.txt",
  "/sitemap.xml",
  "/icon(.*)",
  "/apple-icon(.*)",
]);

function getReturnTo(req: NextRequest) {
  return `${req.nextUrl.pathname}${req.nextUrl.search || ""}`;
}

function readAuth(auth: any) {
  // Clerk middleware API differs across versions:
  // sometimes auth is an object, sometimes a function returning an object.
  const a = typeof auth === "function" ? auth() : auth;
  const userId = a?.userId ?? null;
  const orgId = a?.orgId ?? null;
  return { a, userId, orgId };
}

export default clerkMiddleware((auth: any, req: NextRequest) => {
  const pathname = req.nextUrl.pathname;

  if (isPublicRoute(req)) {
    return NextResponse.next();
  }

  const { a, userId, orgId } = readAuth(auth);

  // 🔎 DEBUG HEADER: lets you prove middleware sees the session
  const resNext = NextResponse.next();
  resNext.headers.set("x-truvern-mw-user", userId ? "yes" : "no");
  resNext.headers.set("x-truvern-mw-org", orgId ? "yes" : "no");

  // If not signed in, route to PUBLIC /auth launcher
  if (!userId) {
    const url = new URL("/auth", req.url);
    url.searchParams.set("mode", "signin");
    url.searchParams.set("returnTo", getReturnTo(req));
    return NextResponse.redirect(url);
  }

  // Signed in but no org selected -> /select-org
  if (!orgId && !pathname.startsWith("/select-org")) {
    const url = new URL("/select-org", req.url);
    url.searchParams.set("returnTo", getReturnTo(req));
    return NextResponse.redirect(url);
  }

  // Protect everything else (Clerk will enforce)
  if (a?.protect) {
    return a.protect();
  }

  return resNext;
});

export const config = {
  matcher: [
    "/((?!.*\\..*|_next|icon|apple-icon).*)",
    "/",
    "/(api|trpc)(.*)",
  ],
};
