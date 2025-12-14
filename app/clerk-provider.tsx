// app/clerk-provider.tsx
"use client";

import type { ReactNode } from "react";
import { ClerkProvider } from "@clerk/nextjs";

type Props = {
  children: ReactNode;
};

// Truvern-wide Clerk appearance (no @clerk/themes needed)
const truvernClerkAppearance = {
  variables: {
    colorPrimary: "#0ea5e9", // sky-500
    colorBackground: "transparent",
    colorText: "#e5e7eb", // slate-200
    colorTextSecondary: "#9ca3af", // slate-400
    colorDanger: "#f97373",
    borderRadius: "999px",
    fontFamily:
      'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
  },
  elements: {
    rootBox: "min-h-screen flex items-center justify-center bg-slate-950",
    card:
      "bg-slate-950/95 border border-slate-800 shadow-xl shadow-slate-950/60 " +
      "rounded-3xl w-full max-w-md mx-auto",
    headerTitle: "text-slate-50 text-2xl font-semibold",
    headerSubtitle: "text-slate-400 text-sm",
    socialButtonsBlockButton:
      "bg-slate-900 hover:bg-slate-800 border border-slate-700 text-slate-100",
    socialButtonsBlockButtonText: "text-sm font-medium",
    formFieldLabel: "text-slate-200 text-xs font-medium",
    formFieldInput:
      "bg-slate-950 border border-slate-700 text-slate-50 text-sm rounded-xl " +
      "px-3 py-2 placeholder:text-slate-500 focus:border-sky-400 " +
      "focus:ring-1 focus:ring-sky-500",
    formFieldInput__error: "border-rose-500",
    formFieldError: "text-rose-400 text-xs mt-1",
    formButtonPrimary:
      "bg-sky-500 hover:bg-sky-400 text-slate-950 text-sm font-medium " +
      "rounded-full px-4 py-2.5 w-full",
    footer: "hidden", // hide default Clerk footer to keep it clean
    cardBox: "p-6 sm:p-8",
    form: "space-y-4",
  },
};

export default function TruvernClerkProvider({ children }: Props) {
  return (
    <ClerkProvider
      appearance={truvernClerkAppearance}
      signInUrl="/sign-in"
      signUpUrl="/sign-up"
      signInFallbackRedirectUrl="/vendors"
      signUpFallbackRedirectUrl="/vendors"
    >
      {children}
    </ClerkProvider>
  );
}
