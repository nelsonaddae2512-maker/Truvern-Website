// middleware.ts
import { clerkMiddleware } from "@clerk/nextjs/server";

export default clerkMiddleware({
  publicRoutes: [
    "/",                // home
    "/trust-network",
    "/vendors",         // vendor list (marketing shell, still fine)
    "/pricing",
    "/contact",
    "/login",
    "/sign-up",
    // ✅ Make all trust links public
    "/trust(.*)",
    // Optionally: allow the trust-link API to be called without auth
    "/api/trust-link",
    "/api/public/vendor",
  ],
});

export const config = {
  matcher: [
    // Run middleware on all routes except static files and _next
    "/((?!.*\\..*|_next).*)",
    "/",
    "/(api|trpc)(.*)",
  ],
};
