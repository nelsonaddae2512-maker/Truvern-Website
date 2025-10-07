export const runtime = "nodejs";
export const dynamic = "force-dynamic";
import { NextResponse } from "next/server";
import * as saml from "samlify";

import crypto from "crypto";
type Org = { id: string | number; name: string; plan?: string; seats?: number };

saml.setSchemaValidator({ validate: () => Promise.resolve('skipped-for-demo') });

function getSp(){
  return saml.ServiceProvider({
    entityID: process.env.SAML_SP_ENTITY_ID || "http://localhost:3000/sso/saml",
    assertionConsumerService: [{
  Binding: saml.Constants.namespace.binding.post,
  Location: process.env.SAML_ACS_URL || "http://localhost:3000/api/sso/saml/acs"
}]
  });
}
function getIdp(){
  return saml.IdentityProvider({
    entityID: process.env.SAML_IDP_ENTITY_ID || "urn:idp:example",
    singleSignOnService: [{ Binding: saml.Constants.namespace.binding.post, Location: process.env.SAML_IDP_SSO_URL || "https://idp.example.com/sso" }],
    signingCert: process.env.SAML_IDP_CERT ? [process.env.SAML_IDP_CERT] : []
  });
}


async function ensureOrgForEmail(email: string){
  const domain = email.split('@')[1]?.toLowerCase() || 'unknown';
  const name = `${domain} Org (SSO)`;
  let org = await prisma.organization.findFirst({ where: { name } });
  if(!org){ org = await prisma.organization.create({ data: { name, plan: 'pro', seats: 9999 } }); }
  return org as Org;
}
function signPayload(obj: any){

  const body = Buffer.from(JSON.stringify(obj)).toString('base64url');
  const secret = process.env.SAML_SESSION_SECRET || process.env.INVITE_SECRET || 'dev_secret';
  const sig = crypto.createHmac('sha256', secret).update(body).digest('base64url');
  return `${body}.${sig}`;
}

export async function POST(req: Request){ const { prisma } = await import("@/lib/prisma"); 
  const form = await req.formData();
  const SAMLResponse = String(form.get('SAMLResponse') || '');
  if(!SAMLResponse) return NextResponse.json({ error: 'Missing SAMLResponse' }, { status: 400 });
  const sp = getSp(); const idp = getIdp();
  try{
    const { extract } = await sp.parseLoginResponse(idp, 'post', { body: { SAMLResponse } });
    const emailAttr = process.env.SAML_EMAIL_ATTRIBUTE || 'urn:oid:0.9.2342.19200300.100.1.3';
    const email = (extract.attributes[emailAttr] || extract.attributes.email || extract.nameID) as string | undefined;
    if(!email) return NextResponse.json({ error: 'Email not found in assertion' }, { status: 400 });

    // Ensure user exists
    let user = await prisma.user.findUnique({ where: { email } });
    if(!user){ user = await prisma.user.create({ data: { email } }); }
    const org = await ensureOrgForEmail(email);
    const has = await prisma.membership.findFirst({ where: { userId: user.id, organizationId: org.id } });
    if(!has){ await prisma.membership.create({ data: { userId: user.id, organizationId: org.id, role: 'MEMBER' } }); }

    // Hand off to NextAuth Credentials provider
    const token = signPayload({ email });
    const base = process.env.NEXTAUTH_URL || 'http://localhost:3000';
    const url = `${base}/api/auth/callback/saml-cred?token=${encodeURIComponent(token)}`;
    return NextResponse.redirect(url, { status: 302 });
  }catch(e:any){
    return NextResponse.json({ error: 'SAML parse failed', detail: e?.message }, { status: 400 });
  }
}

export async function GET(){ return new Response('{"ok":true}',{ status:200, headers:{ "Content-Type":"application/json" }}); }
