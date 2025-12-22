import { SignUp } from "@clerk/nextjs";

export const runtime = "nodejs";

export default function Page() {
  return (
    <div className="min-h-screen bg-slate-950 flex items-center justify-center p-6">
      <SignUp routing="path" path="/sign-up" />
    </div>
  );
}
