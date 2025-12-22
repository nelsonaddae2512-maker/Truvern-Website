"use client";

import { SignIn, SignUp, useAuth } from "@clerk/nextjs";
import { useSearchParams } from "next/navigation";
import { useEffect, Suspense, useMemo } from "react";

function safeDecode(v: string) {
  try {
    return decodeURIComponent(v);
  } catch {
    return v;
  }
}

function sanitizeReturnTo(v: string) {
  // decode (sometimes returnTo is already decoded; safe either way)
  let s = safeDecode(v || "/").trim();

  // block absolute URLs (open-redirect safety)
  if (/^https?:\/\//i.test(s)) return "/";

  // if it looks like "%2Fissues" after one decode (rare), decode again
  if (/%2f/i.test(s)) s = safeDecode(s);

  // ensure leading slash
  if (!s.startsWith("/")) s = "/" + s;

  return s;
}

function AuthInner() {
  const { isLoaded, isSignedIn } = useAuth();
  const params = useSearchParams();

  const mode = (params.get("mode") || "signin").toLowerCase();

  const returnTo = useMemo(() => {
    const raw = params.get("returnTo") || "/";
    return sanitizeReturnTo(raw);
  }, [params]);

  // ✅ HARD NAVIGATION when signed in (avoids App Router + middleware soft-nav loops)
  useEffect(() => {
    if (!isLoaded) return;
    if (isSignedIn) {
      window.location.replace(returnTo);
    }
  }, [isLoaded, isSignedIn, returnTo]);

  if (!isLoaded) return <div className="text-slate-300 text-sm">Loading…</div>;

  // If signed in, we should be leaving immediately; provide a manual link fallback.
  if (isSignedIn) {
    return (
      <div className="text-center">
        <div className="text-slate-300 text-sm">Continuing…</div>
        <a className="mt-3 inline-block text-sky-300 hover:underline" href={returnTo}>
          If you’re stuck, click here →
        </a>
      </div>
    );
  }

  const common = {
    routing: "path" as const,
    path: "/auth",
    afterSignInUrl: returnTo,
    afterSignUpUrl: returnTo,
  };

  const rt = encodeURIComponent(returnTo);

  return (
    <div className="w-full max-w-md">
      {mode === "signup" ? (
        <SignUp {...common} signInUrl={`/auth?mode=signin&returnTo=${rt}`} />
      ) : (
        <SignIn {...common} signUpUrl={`/auth?mode=signup&returnTo=${rt}`} />
      )}
    </div>
  );
}

export default function AuthPage() {
  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-950 px-4 py-10">
      <Suspense fallback={<div className="text-slate-300 text-sm">Loading…</div>}>
        <AuthInner />
      </Suspense>
    </div>
  );
}
