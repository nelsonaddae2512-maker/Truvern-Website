import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/",
  "/pricing(.*)",
  "/contact(.*)",
  "/trust(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",
  "/sign-out(.*)",

  // health/debug
  "/api/health(.*)",
  "/api/whoami(.*)",
  "/api/envcheck(.*)",
  "/api/cookiedebug(.*)",
  "/api/authdebug(.*)",

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
  return auth().protect();
});

export const config = {
  matcher: [
    "/((?!.*\\..*|_next).*)",
    "/",
    "/(api|trpc)(.*)",
  ],
};
