// middleware.ts
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isPublicRoute = createRouteMatcher([
  "/", // home
  "/pricing(.*)",
  "/trust-network(.*)",
  "/vendors(.*)",
  "/board-report(.*)",
  "/issues(.*)",
  "/activity(.*)",
  "/contact(.*)",
  "/sign-in(.*)",
  "/sign-up(.*)",
  "/api/board-report/export(.*)",
]);

export default clerkMiddleware((auth, req) => {
  // Protect everything that's not explicitly public
  if (!isPublicRoute(req)) {
    auth.protect();
  }
});

export const config = {
  matcher: [
    "/((?!_next|.*\\.(?:css|js|json|png|jpg|jpeg|gif|svg|ico|webp|map|txt|woff|woff2)).*)",
    "/(api|trpc)(.*)",
  ],
};
