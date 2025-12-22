// app/(clerk)/sign-in/[[...sign-in]]/page.tsx
import { SignIn } from "@clerk/nextjs";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export const revalidate = 0;

type SP = Record<string, string | string[] | undefined>;

function pickString(v: string | string[] | undefined): string | null {
  if (!v) return null;
  return Array.isArray(v) ? (v[0] ?? null) : v;
}

export default function SignInPage({ searchParams }: { searchParams?: SP }) {
  // Next passes searchParams as a plain object (NOT URLSearchParams)
  const redirectUrl =
    pickString(searchParams?.redirect_url) ??
    pickString(searchParams?.redirectUrl) ??
    "/issues";

  return (
    <main className="min-h-screen bg-slate-950 flex items-center justify-center px-6 py-10">
      <div className="w-full max-w-md">
        <SignIn redirectUrl={redirectUrl} />
      </div>
    </main>
  );
}
