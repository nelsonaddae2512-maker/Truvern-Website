/* eslint-disable */
// @ts-nocheck
// Force-disable all Next.js route type inference for invite page

export const dynamic = 'force-dynamic';

export default function InvitePage({ params }: any) {
  const token = params?.token ?? 'missing';
  return (
    <main style={{ padding: '2rem', fontFamily: 'sans-serif' }}>
      <h1>Vendor Invite</h1>
      <p>This route validates your Truvern invite token.</p>
      <p><strong>Token:</strong> <code>{token}</code></p>
    </main>
  );
}