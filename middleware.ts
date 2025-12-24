import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/",
  "/pricing(.*)",
  "/contact(.*)",
  "/trust(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",
  "/select-org(.*)",

  // allow health/debug endpoints
  "/api/health(.*)",
  "/api/envcheck(.*)",
  "/api/whoami(.*)",
]);

export default clerkMiddleware((auth, req) => {
  // ✅ DEV BYPASS for local PowerShell scripts (only in non-prod)
  const devKey = req.headers.get("x-dev-seed-key");
  if (process.env.NODE_ENV !== "production" && devKey === "local-dev") {
    // Let API routes pass without Clerk (for seed/dev scripts)
    if (req.nextUrl.pathname.startsWith("/api/")) return;
  }

  // Public routes are allowed
  if (isPublicRoute(req)) return;

  // Everything else requires auth
  auth.protect();
});

export const config = {
  matcher: [
    // Skip Next internals and static files
    "/((?!_next|.*\\..*).*)",
    // Always run for API
    "/(api|trpc)(.*)",
  ],
};
