/**
 * Email stub for local and production build.
 * Fixes "Cannot find module '@/lib/email'" errors.
 */

export async function sendInviteEmail(to: string, token: string): Promise<void> {
  console.log(`[mock-email] Sending invite to: ${to} with token: ${token}`);
  // Simulate short async delay
  await new Promise((resolve) => setTimeout(resolve, 200));
  return;
}

export async function sendPasswordResetEmail(to: string, link: string): Promise<void> {
  console.log(`[mock-email] Sending password reset to: ${to} with link: ${link}`);
  await new Promise((resolve) => setTimeout(resolve, 200));
  return;
}

export const mail = {
  sendInviteEmail,
  sendPasswordResetEmail,
};
