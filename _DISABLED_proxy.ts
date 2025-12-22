// proxy.ts
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/", // landing
  "/pricing(.*)",
  "/contact(.*)",
  "/trust(.*)",

  // Clerk pages
  "/sign-in(.*)",
  "/sign-up(.*)",

  // health/debug
  "/api/health(.*)",
  "/api/whoami(.*)",
  "/api/envcheck(.*)",
  "/api/cookiedebug(.*)",

  // static/public assets
  "/favicon.ico",
  "/robots.txt",
  "/sitemap.xml",
  "/manifest.webmanifest",
  "/icon(.*)",
  "/apple-icon(.*)",
]);

export default clerkMiddleware((auth, req) => {
  if (isPublicRoute(req)) return;
  return auth.protect();
});

export const config = {
  matcher: [
    // exclude files with extensions and _next
    "/((?!.*\\..*|_next).*)",
    "/",
    "/(api|trpc)(.*)",
  ],
};
