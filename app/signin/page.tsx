// app/signin/page.tsx
import { redirect } from "next/navigation";

export default function LegacySigninRedirect() {
  // Normalize old /signin → /sign-in
  redirect("/sign-in");
}
