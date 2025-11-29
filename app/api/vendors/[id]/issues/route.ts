import { NextRequest, NextResponse } from "next/server";
import { prisma } from "@/lib/prisma";

export const runtime = "nodejs";

function param(url: URL, s: string) {
  const p = url.pathname.split("/").filter(Boolean);
  const i = p.indexOf(s);
  return i < 0 ? null : p[i + 1];
}

// GET issues
export async function GET(req: NextRequest) {
  const vendorId = param(req.nextUrl, "vendors");
  if (!vendorId) return NextResponse.json({ error: "Missing vendor ID" }, { status: 400 });

  try {
    const issues = await prisma.issue.findMany({
      where: { vendorId: Number(vendorId) },
      orderBy: { createdAt: "desc" },
    });

    return NextResponse.json(issues, { status: 200 });
  } catch (err) {
    console.error("GET issues failed:", err);
    return NextResponse.json({ error: "Failed to load issues" }, { status: 500 });
  }
}

// POST issue
export async function POST(req: NextRequest) {
  const vendorId = param(req.nextUrl, "vendors");
  if (!vendorId) return NextResponse.json({ error: "Missing vendor ID" }, { status: 400 });

  const body = await req.json().catch(() => ({}));

  if (!body.title || !body.severity)
    return NextResponse.json({ error: "Missing title or severity" }, { status: 400 });

  try {
    const created = await prisma.issue.create({
      data: {
        vendorId: Number(vendorId),
        title: body.title,
        severity: body.severity,
        status: "Open",
        dueDate: body.dueDate ? new Date(body.dueDate) : null,
      },
    });

    return NextResponse.json(created, { status: 201 });
  } catch (err) {
    console.error("POST issue failed:", err);
    return NextResponse.json({ error: "Failed to create issue" }, { status: 500 });
  }
}
