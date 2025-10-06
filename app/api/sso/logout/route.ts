
export async function POST(){
  // In real deployment, clear your app session and optionally initiate IdP logout
  return new Response(null, { status: 204 });
}
