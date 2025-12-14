// lib/email.ts

type InvitePayload = {
  email: string;
  token: string;
  organizationId?: string | number;
  role?: string;
};

export async function sendInviteEmail(payload: InvitePayload) {
  // Stub: log instead of actually sending email
  console.log("[Truvern] Mock invite email", payload);
}

export default { sendInviteEmail };
