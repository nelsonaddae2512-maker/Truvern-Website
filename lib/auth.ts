
import type { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import EmailProvider from "next-auth/providers/email";
import { PrismaAdapter } from "@next-auth/prisma-adapter";
import { prisma } from "@/lib/prisma";
import { sendMagicLinkEmail } from "@/lib/email";
import crypto from "crypto";

function domainAllowed(email: string){
  const allow = (process.env.ALLOWED_EMAIL_DOMAINS || '').split(',').map(s=>s.trim().toLowerCase()).filter(Boolean);
  if(!allow.length) return true;
  const d = email.split('@')[1]?.toLowerCase();
  return !!d && allow.includes(d);
}

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  session: { strategy: "jwt" },
  providers: [
    CredentialsProvider({
      id: 'saml-cred',
      name: 'SAML',
      credentials: { token: { label: 'token', type: 'text' } },
      async authorize(creds) {
        const token = (creds as any)?.token as string | undefined;
        if (!token) return null;
        try{
          const [body, sig] = token.split('.');
const secret = process.env.SAML_SESSION_SECRET || process.env.INVITE_SECRET || "dev_secret";

          const expected = crypto.createHmac('sha256', (process.env.SAML_SESSION_SECRET || process.env.INVITE_SECRET || 'dev_secret')).update(body).digest("base64url");
        }catch{}

        const parts = token.split('.');
        if(parts.length !== 2) return null;
        const body = Buffer.from(parts[0], 'base64url').toString('utf8');
        const given = Buffer.from(parts[1], 'base64url');
        const expected = crypto.createHmac('sha256', (process.env.SAML_SESSION_SECRET || process.env.INVITE_SECRET || 'dev_secret')).update(parts[0]).digest();
        if(!crypto.timingSafeEqual(expected, given)) return null;
        const data = JSON.parse(body);
        const email = String(data.email||'').toLowerCase();
        if(!email) return null;
        // Ensure a user
        const { prisma } = require('@/lib/prisma');
        let user = await prisma.user.findUnique({ where: { email } });
        if(!user){ user = await prisma.user.create({ data: { email } }); }
        return { id: user.id, email };
      }
    }),

    EmailProvider({
      sendVerificationRequest: async ({ identifier, url }) => { await sendMagicLinkEmail(identifier, url); }
    })
  ],
  pages: { signIn: "/login" },
  callbacks: {
    async signIn({ user, email }){
      const address = String((user as any)?.email ?? '').toLowerCase();
      if(!address) return false;
      if(domainAllowed(address)) return true;
      const invite = await prisma.pendingInvite.findFirst({ where: { email: address, expiresAt: { gt: new Date() } } });
      return !!invite;
    },
    async jwt({ token, user }){
      if(user && user.email){
        const address = user.email.toLowerCase();
        const invite = await prisma.pendingInvite.findFirst({ where: { email: address, expiresAt: { gt: new Date() } } });
        if(invite){
          const u = await prisma.user.findUnique({ where: { email: address } });
          if(u){
            const has = await prisma.membership.findFirst({ where: { userId: u.id, organizationId: invite.organizationId } });
            if(!has){
              await prisma.membership.create({ data: { userId: u.id, organizationId: invite.organizationId, role: invite.role } });
            }
            await prisma.pendingInvite.deleteMany({ where: { email: address, organizationId: invite.organizationId } });
            (token as any).organizationId = invite.organizationId;
            (token as any).role = invite.role;
          }
        } else {
          (token as any).role = (token as any).role || 'MEMBER';
        }
      }
      return token;
    },
    async session({ session, token }){
      (session as any).user = {
        ...session.user,
        organizationId: (token as any).organizationId || null,
        role: (token as any).role || 'MEMBER'
      };
      return session;
    }
  }
};
