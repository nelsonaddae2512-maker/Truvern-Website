// app/signin/page.tsx
import { redirect } from "next/navigation";

export default function LegacySignInRedirect() {
  redirect("/sign-in");
}
