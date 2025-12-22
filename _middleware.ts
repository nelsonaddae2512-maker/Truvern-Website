// middleware.ts
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/", // landing
  "/pricing(.*)",
  "/contact(.*)",
  "/trust(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",

  // health/debug endpoints (keep open if you use them)
  "/api/health(.*)",
  "/api/envcheck(.*)",
  "/api/whoami(.*)",
  "/api/cookiedebug(.*)",
]);

export default clerkMiddleware((auth, req) => {
  if (isPublicRoute(req)) return;

  // Protect everything else (this is what makes SSR auth consistent)
  return auth.protect();
});

export const config = {
  matcher: [
    // Run middleware on all routes except static files and _next
    "/((?!.*\\..*|_next).*)",
    "/",
    "/(api|trpc)(.*)",
  ],
};
