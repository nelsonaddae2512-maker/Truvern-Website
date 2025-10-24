import { NextResponse } from "next/server";
import { prisma } from "../../../../lib/db";

type Body = {
  companyName?: string;
  contactEmail?: string;
  answersJson?: unknown;
  [key: string]: unknown;
};

export async function POST(req: Request) {
  try {
    const body = (await req.json().catch(() => ({}))) as Body;

    const companyName = String(body.companyName ?? "").trim();
    const contactEmail = String(body.contactEmail ?? "").trim();
    const answersJson = body.answersJson ?? body;

    if (!companyName || !contactEmail) {
      return NextResponse.json(
        { error: "companyName and contactEmail are required" },
        { status: 400 }
      );
    }

    const rec = await prisma.assessmentSubmission.create({
      data: { companyName, contactEmail, answersJson: answersJson as any },
    });

    const url = new URL(req.url);
    const resultsUrl = new URL(`/assessment/results?id=${rec.id}`, url.origin);
    return NextResponse.redirect(resultsUrl);
    // Or: return NextResponse.json({ id: rec.id });
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: "Failed to submit" }, { status: 500 });
  }
}