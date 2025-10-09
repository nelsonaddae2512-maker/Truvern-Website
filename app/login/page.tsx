export const dynamic = "force-dynamic";

export default function Page(){
  return (
    <main className="p-8 max-w-md mx-auto text-center">
      <h1 className="text-3xl font-semibold">Login</h1>
      <p className="mt-3 text-neutral-700">
        Sign in is currently email-based. If SSO is configured for your org, use your company email.
      </p>
      <form className="mt-6 grid gap-3" action="/api/auth/signin/email" method="POST">
        <input className="border rounded-lg px-4 py-3" name="email" type="email" placeholder="you@company.com" required />
        <button className="px-5 py-3 rounded-lg bg-black text-white" type="submit">Send Magic Link</button>
      </form>
    </main>
  );
}