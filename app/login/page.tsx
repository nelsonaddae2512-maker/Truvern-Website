// app/login/page.tsx
import { redirect } from "next/navigation";

export default function LegacyLoginRedirect() {
  redirect("/signin");
}
