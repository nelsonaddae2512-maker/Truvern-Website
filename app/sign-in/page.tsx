import SignInClient from "@/components/auth/sign-in.client";

export const dynamic = "force-dynamic";

export default function Page({
  searchParams,
}: {
  searchParams?: { redirect_url?: string };
}) {
  const redirectUrl = searchParams?.redirect_url || "/vendor";

  return (
    <main className="container-page py-12">
      <div className="max-w-md mx-auto glass-soft rounded-2xl border border-white/10 p-6">
        <h1 className="text-2xl font-semibold mb-4">Sign in</h1>
        <SignInClient redirectUrl={redirectUrl} />
      </div>
    </main>
  );
}
