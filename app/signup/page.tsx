// app/signup/page.tsx
import { redirect } from "next/navigation";

export default function LegacySignupRedirect() {
  // Normalize old /signup → /sign-up
  redirect("/sign-up");
}
