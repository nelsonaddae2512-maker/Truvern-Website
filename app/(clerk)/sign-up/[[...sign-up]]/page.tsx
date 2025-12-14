// app/(clerk)/sign-up/[[...sign-up]]/page.tsx
import { SignUp } from "@clerk/nextjs";

export const metadata = {
  title: "Get started – Truvern",
};

export default function SignUpPage() {
  return (
    <main className="min-h-[calc(100vh-64px)] bg-slate-950 text-slate-50">
      <section className="mx-auto flex max-w-6xl flex-col items-center justify-center px-4 py-12">
        <div className="w-full max-w-md">
          <SignUp
            // Path-based routing: this route is a catch-all [[...sign-up]]
            path="/sign-up"
            routing="path"
            // Where to go if user clicks “Sign in” instead
            signInUrl="/sign-in"
            // Where to land after a successful sign-up
            afterSignUpUrl="/vendors"
          />
        </div>
      </section>
    </main>
  );
}
