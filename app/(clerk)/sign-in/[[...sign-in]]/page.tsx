// app/(clerk)/sign-in/[[...sign-in]]/page.tsx
import { SignIn } from "@clerk/nextjs";

export default function SignInPage() {
  return (
    <main className="flex min-h-[70vh] items-center justify-center px-4 py-12">
      {/* 
        We let Clerk fully control this subtree.
        suppressHydrationWarning tells React to ignore server/client markup
        differences here, which removes the hydration error overlay.
      */}
      <div className="w-full max-w-md" suppressHydrationWarning>
        <SignIn afterSignInUrl="/vendors" />
      </div>
    </main>
  );
}
