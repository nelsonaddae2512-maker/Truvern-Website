import { auth } from "@clerk/nextjs/server";
import { redirect } from "next/navigation";

/**
 * Require a signed-in user AND an active organization context.
 * - If not signed in -> redirect to /sign-in
 * - If signed in but no org selected -> redirect to /select-org
 */
export function requireOrgContext() {
  const a: any = auth();
  const userId = a?.userId ?? null;
  const orgId = a?.orgId ?? null;

  if (!userId) redirect("/sign-in");
  if (!orgId) redirect("/select-org");

  return { userId, orgId, orgRole: a?.orgRole ?? null };
}

/**
 * Require org context + admin-ish role.
 * Clerk org roles often look like: "org:admin", "org:member"
 * Adjust if your instance uses different roles.
 */
export function requireOrgAdmin() {
  const ctx = requireOrgContext();
  const role = String(ctx.orgRole ?? "");

  if (role && role !== "org:admin") {
    // If you later add a nicer page, redirect there.
    redirect("/select-org");
  }

  return ctx;
}