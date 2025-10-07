export const runtime = "nodejs";
export const dynamic = "force-dynamic";

// Build-safe GET (no top-level heavy imports)
export async function GET() {
  return new Response(JSON.stringify({ ok: true, usage: [] }), {
    status: 200,
    headers: { "Content-Type": "application/json" }
  });
}

// Example POST (lazy import anything heavy inside the handler if you add logic)
export async function POST(req: Request) {
  try {
    const body = await req.json().catch(() => ({}));
    // TODO: do something with `body`
    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });
  } catch {
    return new Response(JSON.stringify({ ok: false, error: "internal" }), {
      status: 200,
      headers: { "Content-Type": "application/json" }
    });
  }
}