// middleware.ts
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/", // landing
  "/pricing(.*)",
  "/contact(.*)",
  "/trust(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",
  "/select-org(.*)",

  // health/debug
  "/api/health(.*)",
  "/api/whoami(.*)",
  "/api/cookiedebug(.*)",

  // static assets
  "/favicon.ico",
  "/robots.txt",
  "/sitemap.xml",
]);

export default clerkMiddleware((auth, req) => {
  if (isPublicRoute(req)) return;
  return auth.protect();
});

export const config = {
  matcher: [
    "/((?!.*\\..*|_next).*)",
    "/(api|trpc)(.*)",
  ],
};
