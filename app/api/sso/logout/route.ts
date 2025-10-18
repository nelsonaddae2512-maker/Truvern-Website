export const runtime = "nodejs";
export const dynamic = "force-dynamic";
export async function POST(){
  // In real deployment, clear your app session and optionally initiate IdP logout
  return new Response(null, { status: 204 });
}

export async function GET(){ return new Response('{"ok":true}',{ status:200, headers:{ "Content-Type":"application/json" }}); }


