
import { withAuth } from "next-auth/middleware";

export default withAuth({
  pages: { signIn: "/login" }
});

export const config = {
  matcher: ["/dashboard/:path*"]
};

export async function middleware(request: Request) {
  // Security headers for all responses handled by Next (best effort)
  const res = Response.next();
  res.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  res.headers.set("X-Content-Type-Options", "nosniff");
  res.headers.set("X-Frame-Options", "SAMEORIGIN");
  res.headers.set("X-XSS-Protection", "0");
  return res;
}
