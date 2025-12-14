// app/onboarding/welcome/page.tsx
import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";

export default async function OnboardingWelcomePage() {
  const { userId } = auth();

  // If somehow unauthenticated, send back to sign-in
  if (!userId) {
    redirect("/signin");
  }

  /**
   * Phase221 (next step):
   * ---------------------
   * Here we will:
   *  - Create the Organization row if one does not exist
   *  - Create the User row linked to Clerk userId
   *  - Create OrgMembership / OrgRole with ADMIN for this user
   *
   * For now, we just send them into the app with the onboarding flag.
   */

  redirect("/vendors?onboarding=1");
}
