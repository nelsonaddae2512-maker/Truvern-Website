// middleware.ts
import { NextResponse } from "next/server";
import { clerkMiddleware, createRouteMatcher } from "@clerk/nextjs/server";

const isProtectedRoute = createRouteMatcher([
  "/vendors(.*)",
  "/reports(.*)",
  "/trust-network(.*)",
  "/dashboard(.*)",
]);

export default clerkMiddleware((auth, req) => {
  // Only protect the routes we care about
  if (!isProtectedRoute(req)) {
    return NextResponse.next();
  }

  const { userId } = auth();

  // Not signed in → send to /signin and preserve the original URL
  if (!userId) {
    const signInUrl = new URL("/signin", req.url);
    signInUrl.searchParams.set("redirect_url", req.url);
    return NextResponse.redirect(signInUrl);
  }

  // Signed in → continue to the page
  return NextResponse.next();
});

export const config = {
  matcher: [
    // Run on all non-static routes plus API
    "/((?!.*\\..*|_next).*)",
    "/",
    "/(api|trpc)(.*)",
  ],
};
