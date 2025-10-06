
import { Resend } from 'resend';
const resendKey = process.env.RESEND_API_KEY;
const from = process.env.EMAIL_FROM || 'security@truvern.com';
export async function sendMagicLinkEmail(email: string, url: string){
  if(!resendKey) throw new Error('RESEND_API_KEY missing');
  const resend = new Resend(resendKey);
  const html = `<div style="font-family:Inter, Arial, sans-serif;line-height:1.5;color:#0f172a">
    <h2>Sign in to Truvern</h2>
    <p>Click the secure link below to sign in:</p>
    <p><a href="${url}" style="background:#0f172a;color:#fff;padding:10px 14px;border-radius:8px;text-decoration:none">Sign in</a></p>
    <p style="font-size:12px;color:#64748b">If you did not request this, you can safely ignore this email.</p>
  </div>`;
  await resend.emails.send({ from, to: email, subject: "Your secure sign‑in link", html });
}
