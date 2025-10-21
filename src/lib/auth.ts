import NextAuth, { type AuthOptions } from "next-auth";
import Credentials from "next-auth/providers/credentials";

export const authOptions: AuthOptions = {
  providers: [
    Credentials({
      name: "Credentials",
      credentials: {
        email: { label: "Email", type: "text" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        if (
          credentials?.email === "admin@truvern.com" &&
          credentials?.password === "Rushmangps25122513%Nelsonaddae25122513%"
        ) {
          return { id: "1", name: "Admin", email: "admin@truvern.com" };
        }
        return null;
      }
    })
  ],
  session: { strategy: "jwt" as const },
  pages: { signIn: "/login" }
};