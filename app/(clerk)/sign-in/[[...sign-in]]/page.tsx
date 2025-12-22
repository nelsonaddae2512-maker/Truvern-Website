// app/(clerk)/sign-in/[[...sign-in]]/page.tsx
import { SignIn } from "@clerk/nextjs";

export const runtime = "nodejs";

export default function Page() {
  return (
    <div className="min-h-[calc(100vh-64px)] bg-slate-950 flex items-center justify-center p-6">
      <SignIn routing="path" path="/sign-in" redirectUrl="/vendors" />
    </div>
  );
}
