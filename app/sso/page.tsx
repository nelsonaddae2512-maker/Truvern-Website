
export default function SSOSettings(){
  return (
    <div className="max-w-3xl mx-auto p-8 space-y-3">
      <h1 className="text-3xl font-bold">SSO / SAML (Preview)</h1>
      <p className="text-slate-600">Enterprise plan can enable SAML SSO. Download basic SP metadata below and contact support to complete IdP setup.</p>
      <a href="/api/sso/saml/metadata" className="underline text-sm">Download SP metadata XML</a>
      <div className="text-xs text-slate-500">Full ACS/Logout endpoints and certificate management are stubs in this demo.</div>
    </div>
  );
}


