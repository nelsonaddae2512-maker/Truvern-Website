import { NextResponse } from "next/server";
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/", // landing
  "/pricing(.*)",
  "/contact(.*)",
  "/trust(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",

  "/select-org(.*)",

  "/api/health(.*)",
  "/api/whoami(.*)",
  "/api/envcheck(.*)",
  "/api/cookiedebug(.*)",

  "/favicon.ico",
  "/robots.txt",
  "/sitemap.xml",
  "/manifest.webmanifest",
  "/icon(.*)",
  "/apple-icon(.*)",
]);

export default clerkMiddleware(
  async (auth, req) => {
    if (isPublicRoute(req)) {
      return NextResponse.next();
    }

    // IMPORTANT: don't "return auth.protect()"
    // protect() may resolve to void; always return a Response after awaiting it
    await auth.protect();
    return NextResponse.next();
  },
  { debug: true }
);

export const config = {
  matcher: [
    "/((?!.*\\..*|_next|icon|apple-icon).*)",
    "/",
    "/(api|trpc)(.*)",
  ],
};
