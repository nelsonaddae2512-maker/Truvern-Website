// middleware.ts
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/", // landing
  "/pricing(.*)",
  "/contact(.*)",
  "/trust(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",

  // keep diagnostics reachable
  "/api/health(.*)",
  "/api/envcheck(.*)",
  "/api/whoami(.*)",
  "/api/cookiedebug(.*)",
]);

export default clerkMiddleware((auth, req) => {
  if (isPublicRoute(req)) return;
  return auth.protect();
});

export const config = {
  matcher: [
    // run on all app + api routes, skip static files and _next
    "/((?!.*\\..*|_next).*)",
    "/",
    "/(api|trpc)(.*)",
  ],
};
