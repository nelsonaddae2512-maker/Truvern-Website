export const runtime = "nodejs";          // NextAuth requires Node runtime
export const dynamic = "force-dynamic";   // never statically analyze this route

import NextAuth from "next-auth";
import { authOptions } from "@/lib/auth";

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };