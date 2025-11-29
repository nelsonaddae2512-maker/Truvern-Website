import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

function param(url: URL, seg: string) {
  const p = url.pathname.split("/").filter(Boolean);
  const i = p.indexOf(seg);
  return i < 0 ? null : p[i + 1];
}

export async function PATCH(req: NextRequest) {
  const url = req.nextUrl;

  const vendorId = param(url, "vendors");
  const issueId = param(url, "issues");

  if (!vendorId || !issueId)
    return NextResponse.json({ error: "Missing vendor or issue ID" }, { status: 400 });

  const body = await req.json().catch(() => ({}));

  if (!body.status)
    return NextResponse.json({ error: "Missing status" }, { status: 400 });

  try {
    const updated = await prisma.issue.update({
      where: { id: Number(issueId) },
      data: { status: body.status },
    });

    return NextResponse.json(updated, { status: 200 });
  } catch (err) {
    console.error("PATCH issue status failed:", err);
    return NextResponse.json({ error: "Failed to update status" }, { status: 500 });
  }
}
