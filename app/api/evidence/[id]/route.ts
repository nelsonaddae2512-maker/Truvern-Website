// app/api/evidence/[id]/route.ts
import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

interface RouteParams {
  params: { id: string };
}

// GET /api/evidence/:id
// - If the request is a browser navigation (text/html), redirect to fileUrl
// - If the request asks for JSON (application/json), return the evidence JSON
export async function GET(req: NextRequest, { params }: RouteParams) {
  const id = Number(params.id);

  if (!Number.isFinite(id)) {
    return NextResponse.json({ error: "Invalid evidence id" }, { status: 400 });
  }

  const evidence = await prisma.evidence.findUnique({
    where: { id },
  });

  if (!evidence) {
    return NextResponse.json(
      { error: "Evidence not found" },
      { status: 404 }
    );
  }

  const accept = req.headers.get("accept") || "";

  // If this is a programmatic fetch asking for JSON, return JSON.
  if (accept.includes("application/json")) {
    return NextResponse.json({ evidence });
  }

  // Otherwise (browser navigation / link click), redirect to the fileUrl if present.
  if (evidence.fileUrl) {
    return NextResponse.redirect(evidence.fileUrl, { status: 302 });
  }

  // Fallback: no file URL – just show JSON detail.
  return NextResponse.json({ evidence });
}
