import prisma from "@/lib/db";

export const runtime = "nodejs"
export const dynamic = "force-dynamic"
export async function GET(){
  const xml = `<?xml version="1.0"?>
<EntityDescriptor entityID="https://truvern.com/sso/saml" xmlns="urn:oasis:names:tc:SAML:2.0:metadata">
  <SPSSODescriptor AuthnRequestsSigned="false" WantAssertionsSigned="true" protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
    <NameIDFormat>urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress</NameIDFormat>
    <AssertionConsumerService index="1" isDefault="true" Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" Location="https://truvern.com/api/sso/saml/acs"/>
  </SPSSODescriptor>
</EntityDescriptor>`;
  return new Response(xml, { headers: { 'content-type':'application/samlmetadata+xml' } });
}

